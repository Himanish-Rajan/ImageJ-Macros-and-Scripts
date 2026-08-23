#@ Dataset image
#@ DatasetService datasetService
#@ DisplayService displayService
#@ UIService uiService
#@ org.scijava.object.ObjectService objectService

import org.apposed.appose.Appose
import net.imglib2.appose.ShmImg
import net.imglib2.appose.NDArrays
import ij.WindowManager

// ── Environment ───────────────────────────────────────────────────────────────
println("== Building Environment ==")
pixiToml = """
[workspace]
authors = ["CodeBlocker007 <md23b013@smail.iitm.ac.in>"]
channels = ["conda-forge"]
name = "THUNDER"
platforms = ["win-64","linux-64","osx-arm64"]
version = "1.5.0"

[tasks]

[dependencies]
python = "==3.12.12"
tifffile = "==2026.2.16"
scipy = "==1.16.3"
numpy = "==2.0.2"
appose = "==0.7.2"
matplotlib = ">=3.10.8,<4"

[environments]
"""
env = Appose.pixi().content(pixiToml).logDebug().build()
println("Environment build complete: ${env.base()}")

// ── Python Script ─────────────────────────────────────────────────────────────
thunder_script = """
import numpy as np
from scipy.fft import fft2, ifft2

report = print
def listen(callback):
    global report
    report = callback

appose_mode = 'task' in globals()
if appose_mode:
    listen(task.update)
else:
    from appose.python_worker import Task
    task = Task()

def leica_thunder_algo(I, ker, s=0.05, single_threaded_fft = False):
    alpha   = 0.493
    maxiter = 100
    err     = 1
    k       = 0
    tol     = 1e-3

    I_min = I.min()
    I_max = I.max()
    img   = (I - I_min) / (I_max - I_min + 1e-12)

    ImgEst = img.copy()
    D      = np.zeros_like(img)

    while err > tol and k < maxiter:
        prev_ImgEst  = ImgEst.copy()
        if single_threaded_fft:
            ImgEst_fft = fft2(img + D, workers=1) * ker
            ImgEst     = np.real(ifft2(ImgEst_fft, workers=1))
        else:
            ImgEst_fft = fft2(img + D) * ker
            ImgEst     = np.real(ifft2(ImgEst_fft))
        error        = img - ImgEst
        mask         = np.abs(error) <= s
        D            = np.where(mask, (2*alpha - 1)*(img - ImgEst), (ImgEst - img))
        err          = np.linalg.norm(prev_ImgEst - ImgEst) / np.linalg.norm(ImgEst + prev_ImgEst + 1e-12)
        k           += 1

    cleared     = np.clip(img - ImgEst, 0, None)
    cleared_img = cleared * (I_max - I_min) + I_min
    return cleared_img.astype(np.uint16)


def process_stack(gamma=70, s=0.05):
    if appose_mode:
        stack = ndarray.ndarray()
    else:
        raise RuntimeError("Not in appose mode")

    if stack.ndim == 3:
        from multiprocessing.pool import ThreadPool
        import time

        nz, ny, nx = stack.shape
        H          = np.zeros((nx, ny))
        H[0, 0]    = 4
        H[0, 1]    = H[0, -1] = H[1, 0] = H[-1, 0] = -1
        fft_ker    = 1 / (1 + gamma * fft2(H))
        processed  = np.zeros_like(stack, dtype=np.uint16)

        completed  = [0]   # mutable counter for progress reporting

        def process_slice(z):
            result         = leica_thunder_algo(stack[z].copy(), fft_ker.copy(), s, single_threaded_fft=True)
            completed[0]  += 1
            report(f"Processing slice {completed[0]}/{nz}...")
            return z, result

        start = time.time()
        with ThreadPool() as pool:
            for z, result in pool.imap_unordered(process_slice, range(nz)):
                processed[z] = result

        report(f"Done. Time: {time.time() - start:.1f}s")
        return processed
        
    elif stack.ndim == 2:
        ny, nx  = stack.shape
        H       = np.zeros((nx, ny))
        H[0, 0] = 4
        H[0, 1] = H[0, -1] = H[1, 0] = H[-1, 0] = -1
        fft_ker = 1 / (1 + gamma * fft2(H))
        return leica_thunder_algo(stack, fft_ker, s, single_threaded_fft = False)


processed_stack = process_stack(gamma=70, s=0.05)

def share_as_ndarray(stack):
    from appose import NDArray
    shared = NDArray(str(stack.dtype), stack.shape)
    shared.ndarray()[:] = stack
    return shared

if appose_mode:
    out = share_as_ndarray(processed_stack)
    del processed_stack
    task.outputs['proc_img'] = out
"""

println("Loaded THUNDER script of length ${thunder_script.length()}")

// ── Helpers ───────────────────────────────────────────────────────────────────
python       = null
shmHandle    = null
inputs       = null
task         = null
proc_img_mem = null
rawNdArray   = null
baseName     = ""

imgToAppose = { img ->
    def shm = ShmImg.copyOf(img)
    shmHandle = shm
    println("Copied image into shared memory: ${shm.ndArray().shape()}")
    return shm.ndArray()
}

apposeToImg = { ndarray -> NDArrays.asArrayImg(ndarray) }

// ── Main ──────────────────────────────────────────────────────────────────────
println("== STARTING PYTHON SERVICE ==")

try {
    python = env.python()
    inputs = ["ndarray": imgToAppose(image)]

    task = python.task(thunder_script, inputs)
        .listen { if (it.message) println("[THUNDER] ${it.message}") }
        .start()
    task.waitFor()

    println("TASK FINISHED: ${task.status}")
    if (task.error) println(task.error)

    // Transfer result out of shared memory
    rawNdArray   = task.outputs['proc_img']
    def rawView  = apposeToImg(rawNdArray)
    proc_img_mem = rawView.copy()
    rawView      = null

    // Build and display dataset — no script variable holds it after uiService.show()
    baseName     = image.getName()
    def dataset  = datasetService.create(proc_img_mem)
    dataset.setName("Proc_Img_" + baseName)
    proc_img_mem = null
    uiService.show(dataset)   // Fiji owns it, script holds no reference
    dataset      = null

    // ── Cleanup stale outputs from previous runs ───────────────────────────
    // Close stale SciJava displays
    for (display in displayService.getDisplays()) {
        def dName = display.getName()
        if (dName?.startsWith("Proc_Img_") && dName != "Proc_Img_" + baseName) {
            println("Closing stale display: ${dName}")
            display.close()
        }
    }

    // Flush stale legacy ImagePlus from WindowManager
    def allIDs = WindowManager.getIDList()
    if (allIDs) {
        for (id in allIDs) {
            def imp     = WindowManager.getImage(id)
            def impName = imp?.getTitle()
            if (impName?.startsWith("Proc_Img_") && impName != "Proc_Img_" + baseName) {
                println("Flushing legacy ImagePlus: ${impName}")
                imp.flush()
                WindowManager.removeWindow(imp.getWindow())
            }
        }
    }

    // Deregister stale datasets from SciJava object registry
    for (ds in objectService.getObjects(net.imagej.Dataset)) {
        def dsName = ds.getName()
        if (dsName?.startsWith("Proc_Img_") && dsName != "Proc_Img_" + baseName) {
            println("Deregistering stale dataset: ${dsName}")
            objectService.removeObject(ds)
            ds.dispose()
        }
    }

} finally {
    try { rawNdArray?.close()  } catch(e) { println("ndarray close error: ${e}") }
    try { shmHandle?.close()   } catch(e) { println("shm close error: ${e}") }
    try { python?.close()      } catch(e) { println("python close error: ${e}") }
    rawNdArray   = null
    shmHandle    = null
    python       = null
    inputs?.clear()
    inputs       = null
    task         = null
    proc_img_mem = null
    imgToAppose  = null
    apposeToImg  = null
    println("== TERMINATING PYTHON SERVICE ==")
    System.gc()
    System.runFinalization()
    System.gc()
}