# -*- coding: utf-8 -*-
#
#-------------------------------------------------------------------------------
#
#     This file is part of the Code_Saturne User Interface, element of the
#     Code_Saturne CFD tool.
#
#     Copyright (C) 1998-2010 EDF S.A., France
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
- LineEditDelegateVerbosity
- LineEditDelegateSelector
- StandardItemModelFaces
- FacesSelectionView
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from Base.QtPage import RegExpValidator, DoubleValidator
from Base.Toolbox import GuiParam
from Pages.FacesSelectionForm import Ui_FacesSelectionForm
from Pages.SolutionDomainModel import SolutionDomainModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("FacesSelectionView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Line edit delegate for references
#-------------------------------------------------------------------------------

class LineEditDelegateVerbosity(QItemDelegate):
    """
    Use of a QLineEdit in the table.
    """
    def __init__(self, parent=None):
        QItemDelegate.__init__(self, parent)


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        validator =  RegExpValidator(editor, QRegExp("^[0-9 ]*$"))
        editor.setValidator(validator)
        #editor.installEventFilter(self)
        return editor


    def setEditorData(self, lineEdit, index):
        value = index.model().data(index, Qt.DisplayRole).toString()
        lineEdit.setText(value)


    def setModelData(self, lineEdit, model, index):
        value = lineEdit.text()
        model.setData(index, QVariant(value), Qt.DisplayRole)

#-------------------------------------------------------------------------------
# Line edit delegate for selection
#-------------------------------------------------------------------------------

class LineEditDelegateSelector(QItemDelegate):
    """
    Use of a QLineEdit in the table.
    """
    def __init__(self, parent=None):
        QItemDelegate.__init__(self, parent)


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        #validator =  RegExpValidator(editor, QRegExp("[ '_A-Za-z0-9]*"))
        validator =  RegExpValidator(editor, QRegExp("[ -~]*"))
        editor.setValidator(validator)
        #editor.installEventFilter(self)
        return editor


    def setEditorData(self, lineEdit, index):
        value = index.model().data(index, Qt.DisplayRole).toString()
        lineEdit.setText(value)


    def setModelData(self, lineEdit, model, index):
        value = lineEdit.text()
        model.setData(index, QVariant(value), Qt.DisplayRole)

#-------------------------------------------------------------------------------
# Line edit delegate for Fraction and Plane
#-------------------------------------------------------------------------------

class FractionPlaneDelegate(QItemDelegate):
    def __init__(self, parent=None):
        super(FractionPlaneDelegate, self).__init__(parent)


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        validator = DoubleValidator(editor, min=0.)
        validator.setExclusiveMin(True)
        editor.setValidator(validator)
        #editor.installEventFilter(self)
        return editor


    def setEditorData(self, editor, index):
        value = index.model().data(index, Qt.DisplayRole).toString()
        editor.setText(value)


    def setModelData(self, editor, model, index):
        value, ok = editor.text().toDouble()
        if editor.validator().state == QValidator.Acceptable:
            model.setData(index, QVariant(value), Qt.DisplayRole)

#-------------------------------------------------------------------------------
# Model class
#-------------------------------------------------------------------------------

class StandardItemModelFaces(QStandardItemModel):

    def __init__(self, parent, mdl=None, tag=None):
        """
        """
        QStandardItemModel.__init__(self)

        self.parent = parent
        self.mdl = mdl
        self.tag = tag

        self.headers = [self.tr("Fraction"),
                        self.tr("Plane"),
                        self.tr("Verbosity"),
                        self.tr("Visualization"),
                        self.tr("Selection criteria")]

        self.tooltip = [self.tr("Relative merge tolerance"),
                        self.tr("Maximum angle for normals of coplanar faces"),
                        self.tr("Verbosity level"),
                        self.tr("Visualization output level (0 for none)"),
                        self.tr("Selection criteria string")]

        self.setColumnCount(len(self.headers))

        self.dataFaces = []
        if tag and mdl:
            self.populateModel()


    def populateModel(self):

        # Default values
        self.default = {}
        for key in ('selector', 'fraction', 'plane', 'verbosity', 'visualization'):
            self.default[key] = self.mdl.defaultValues()[key]

        if self.tag == "face_joining":
            for j in range(self.mdl.getJoinSelectionsCount()):
                d = self.mdl.getJoinFaces(j)
                self.dataFaces.append(d)
                row = self.rowCount()
                self.setRowCount(row+1)

        elif self.tag == "face_periodicity":
            for j in range(self.mdl.getPeriodicSelectionsCount()):
                d = self.mdl.getPeriodicFaces(j)
                self.dataFaces.append(d)
                row = self.rowCount()
                self.setRowCount(row+1)


    def data(self, index, role):
        if not index.isValid():
            return QVariant()

        row = index.row()
        col = index.column()

        if role == Qt.ToolTipRole:
            return QVariant(self.tooltip[col])

        if role == Qt.DisplayRole:
            if col == 0:
                return QVariant(self.dataFaces[row]['fraction'])
            elif col == 1:
                return QVariant(self.dataFaces[row]['plane'])
            elif col == 2:
                return QVariant(self.dataFaces[row]['verbosity'])
            elif col == 3:
                return QVariant(self.dataFaces[row]['visualization'])
            elif col == 4:
                return QVariant(self.dataFaces[row]['selector'])

        return QVariant()


    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        return Qt.ItemIsEnabled | Qt.ItemIsSelectable | Qt.ItemIsEditable


    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return QVariant(self.headers[section])
        return QVariant()


    def setData(self, index, value, role):
        row = index.row()
        col = index.column()

        if col == 0:
            self.dataFaces[row]['fraction'] = str(value.toString())
        elif col == 1:
            self.dataFaces[row]['plane'] = str(value.toString())
        elif col == 2:
            self.dataFaces[row]['verbosity'] = str(value.toString())
        elif col == 3:
            self.dataFaces[row]['visualization'] = str(value.toString())
        elif col == 4:
            self.dataFaces[row]['selector'] = str(value.toString())

        if self.tag == "face_joining":
            self.mdl.replaceJoinFaces(row, self.dataFaces[row])

        elif self.tag == "face_periodicity":
            self.mdl.replacePeriodicFaces(row, self.dataFaces[row])

        log.debug("setData -> dataFaces = %s" % self.dataFaces)
        self.emit(SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), index, index)
        return True


    def addItem(self):
        """
        Add an item in the QListView.
        """
        title = self.tr("Warning")

        if self.tag == "face_joining":
            self.mdl.addJoinFaces(self.default)

        elif self.tag == "face_periodicity":
            self.mdl.addPeriodicFaces(self.default)

        self.dataFaces.append(self.default.copy())
        log.debug("addItem -> dataFaces = %s" % self.dataFaces)
        row = self.rowCount()
        self.setRowCount(row+1)


    def delItem(self, row):
        """
        Delete an item from the QTableView.
        """
        log.debug("StandardItemModelFaces.delete row = %i %i" % (row, self.mdl.getJoinSelectionsCount()))

        if self.tag == "face_joining":
            self.mdl.deleteJoinFaces(row)
            del self.dataFaces[row]
            row = self.rowCount()
            self.setRowCount(row-1)

        elif self.tag == "face_periodicity":
            self.mdl.deletePeriodicity(row)
            del self.dataFaces[row]
            row = self.rowCount()
            self.setRowCount(row-1)

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class FacesSelectionView(QWidget, Ui_FacesSelectionForm):
    """
    """
    def __init__(self, *args):
        """
        Constructor.
        """
        QWidget.__init__(self, *args)
        Ui_FacesSelectionForm.__init__(self)
        self.setupUi(self)

        self.modelFaces = None

        self.tableView.setModel(self.modelFaces)

        self.tableView.verticalHeader().setResizeMode(QHeaderView.ResizeToContents)
        self.tableView.horizontalHeader().setResizeMode(QHeaderView.ResizeToContents)
        self.tableView.horizontalHeader().setStretchLastSection(True)

        delegateFraction = FractionPlaneDelegate(self.tableView)
        self.tableView.setItemDelegateForColumn(0, delegateFraction)

        delegatePlane = FractionPlaneDelegate(self.tableView)
        self.tableView.setItemDelegateForColumn(1, delegatePlane)

        delegateVerbosity = LineEditDelegateVerbosity(self.tableView)
        self.tableView.setItemDelegateForColumn(2, delegateVerbosity)
        self.tableView.setItemDelegateForColumn(3, delegateVerbosity)

        delegateSelector = LineEditDelegateSelector(self.tableView)
        self.tableView.setItemDelegateForColumn(4, delegateSelector)

        self.tableView.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.tableView.setSelectionMode(QAbstractItemView.SingleSelection)

        # Connections

        self.connect(self.pushButtonAdd,    SIGNAL("clicked()"), self.slotAddItem)
        self.connect(self.pushButtonDelete, SIGNAL("clicked()"), self.slotDelItem)


#    def populateModel(self, model, tag):
#        self.modelFaces.populateModel(model, tag)


    @pyqtSignature("")
    def slotAddItem(self):
        """
        Create a new faces selection.
        """
        self.modelFaces.addItem()


    @pyqtSignature("")
    def slotDelItem(self):
        """
        Delete a single selected row.
        """
        for index in self.tableView.selectionModel().selectedIndexes():
            self.modelFaces.delItem(index.row())
            break


    def tr(self, text):
        """
        Translation
        """
        return text


#-------------------------------------------------------------------------------
# Testing part
#-------------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    app = QApplication(sys.argv)
    FacesSelectionView = FacesSelectionView(app)
    FacesSelectionView.show()
    sys.exit(app.exec_())

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
