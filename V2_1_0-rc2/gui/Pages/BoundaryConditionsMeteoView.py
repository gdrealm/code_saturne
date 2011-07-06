# -*- coding: utf-8 -*-
#
#-------------------------------------------------------------------------------
#
#     This file is part of the Code_Saturne User Interface, element of the
#     Code_Saturne CFD tool.
#
#     Copyright (C) 1998-2009 EDF S.A., France
#
#     contact: saturne-support@edf.fr
#
#     The Code_Saturne User Interface is free software; you can redistribute it
#     and/or modify it under the terms of the GNU General Public License
#     as published by the Free Software Foundation; either version 2 of
#     the License, or (at your option) any later version.
#
#     The Code_Saturne User Interface is distributed in the hope that it will be
#     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with the Code_Saturne Kernel; if not, write to the
#     Free Software Foundation, Inc.,
#     51 Franklin St, Fifth Floor,
#     Boston, MA  02110-1301  USA
#
#-------------------------------------------------------------------------------

"""
This module contains the following classes:
- BoundaryConditionsMeteoView
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import string, logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from Pages.BoundaryConditionsMeteoForm import Ui_BoundaryConditionsMeteoForm
from Pages.AtmosphericFlowsModel import AtmosphericFlowsModel

from Base.Toolbox import GuiParam
from Base.QtPage import DoubleValidator, ComboModel
from Pages.LocalizationModel import LocalizationModel, Zone
from Pages.Boundary import Boundary

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("BoundaryConditionsMeteoView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class BoundaryConditionsMeteoView(QWidget, Ui_BoundaryConditionsMeteoForm):
    """
    Boundary condifition for the velocity part
    """
    def __init__(self, parent):
        """
        Constructor.
        """
        QWidget.__init__(self, parent)

        Ui_BoundaryConditionsMeteoForm.__init__(self)
        self.setupUi(self)


    def setup(self, case, velocityWidget, turbulenceWidget):
        """
        Setup the widget.
        """
        self.__case = case
        self.velocityWidget = velocityWidget
        self.turbulenceWidget = turbulenceWidget
        self.__boundary = None
        self.__model = AtmosphericFlowsModel(self.__case)

        self.connect(self.checkBoxReadData,
                     SIGNAL("clicked(bool)"),
                     self.__slotReadData)
        self.connect(self.checkBoxAutoNature,
                     SIGNAL("clicked(bool)"),
                     self.__slotAutoNature)


    def showWidget(self, b):
        """
        Show the widget.
        """
        self.__b = b
        if self.__model.getAtmosphericFlowsModel() != "off" \
            and self.__model.getMeteoDataStatus() == "on":
            self.show()

            label = b.getLabel()
            nature = "meteo_" + b.getNature()
            self.__boundary = Boundary(nature, label, self.__case)

            if self.__boundary.getMeteoDataStatus() == 'on':
                self.checkBoxReadData.setChecked(True)
                self.checkBoxAutoNature.setEnabled(True)
                self.velocityWidget.hideWidget()
                self.turbulenceWidget.hideWidget()
            else:
                self.checkBoxReadData.setChecked(False)
                self.checkBoxAutoNature.setEnabled(False)
                self.velocityWidget.showWidget(b)
                self.turbulenceWidget.showWidget(b)

            if self.__boundary.getAutomaticNatureStatus() == 'on':
                self.checkBoxAutoNature.setChecked(True)
            else:
                self.checkBoxAutoNature.setChecked(False)

        else:
            self.hideWidget()


    def hideWidget(self):
        """
        Hide all.
        """
        self.hide()


    def __slotReadData(self, bool):
        """
        Input if the meteo data must be read.
        """
        if bool == True:
            self.__boundary.setMeteoDataStatus('on')
            self.checkBoxAutoNature.setEnabled(True)
            self.velocityWidget.hideWidget()
            self.turbulenceWidget.hideWidget()
        else:
            self.__boundary.setMeteoDataStatus('off')
            self.checkBoxAutoNature.setChecked(False)
            self.__boundary.setAutomaticNatureStatus('off')
            self.checkBoxAutoNature.setEnabled(False)
            self.velocityWidget.showWidget(self.__b)
            self.turbulenceWidget.showWidget(self.__b)


    def __slotAutoNature(self, bool):
        """
        Input if the nature of the boundary must be detected automaticaly.
        """
        if bool == True:
            self.__boundary.setAutomaticNatureStatus('on')
        else:
            self.__boundary.setAutomaticNatureStatus('off')


    def tr(self, text):
        """
        Translation.
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
