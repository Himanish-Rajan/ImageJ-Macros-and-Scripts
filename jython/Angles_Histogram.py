import os
from ij import IJ, ImagePlus
from ij.gui import GenericDialog
from ij import WindowManager
from ij.plugin.frame import RoiManager

# ShapeRoi has getSelectionCoordinates for macro
# https://imagej.net/ij/developer/api/ij/ij/gui/ShapeRoi.html
from ij.gui import ShapeRoi

# JFreeChart imports for polar plots
import org.jfree.chart.JFreeChart
import org.jfree.chart.PolarChartPanel
import org.jfree.chart.plot.PolarAxisLocation
import org.jfree.chart.renderer.DefaultPolarItemRenderer
import org.jfree.chart.editor.DefaultPolarPlotEditor

img = WindowManager.getCurrentImage()
