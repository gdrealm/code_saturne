# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------

# This file is part of Code_Saturne, a general-purpose CFD tool.
#
# Copyright (C) 1998-2012 EDF S.A.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA 02110-1301, USA.

#-------------------------------------------------------------------------------

"""
This module defines the Page for the physical properties of the fluid.
These properties can be reference value or initial value

This module contens the following classes and function:
- FluidCaracteristicsModel
- FluidCaracteristicsModelTestCase
"""

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import os, sys, unittest

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from Base.Common import *
import Base.Toolbox as Tool
from Base.XMLvariables import Variables, Model
from Base.XMLmodel import XMLmodel, ModelTest

#-------------------------------------------------------------------------------
# Model class
#-------------------------------------------------------------------------------

class FluidCharacteristicsModel(Variables, Model):
    """
    Class to manipulate Molecular Properties in xml file.
    """
    def __init__(self, case):
        """FluidCharacteristicsModel Constuctor."""
        self.case = case
        self.node_models = self.case.xmlGetNode('thermophysical_models')
        self.node_prop   = self.case.xmlGetNode('physical_properties')
        self.node_fluid  = self.node_prop.xmlInitNode('fluid_properties')
        self.node_comp   = self.node_models.xmlInitNode('compressible_model', 'model')
        self.node_gas    = self.node_models.xmlInitNode('gas_combustion',     'model')
        self.node_coal   = self.node_models.xmlInitNode('solid_fuels',        'model')

        self.node_density   = self.setNewFluidProperty(self.node_fluid, 'density')
        self.node_viscosity = self.setNewFluidProperty(self.node_fluid, 'molecular_viscosity')
        self.node_heat      = self.setNewFluidProperty(self.node_fluid, 'specific_heat')
        self.node_cond      = self.setNewFluidProperty(self.node_fluid, 'thermal_conductivity')


    def __nodeFromTag(self, name):
        """
        Private method : return node with attibute name 'name'
        """
        if self.node_coal['model'] != None and self.node_coal['model'] != 'off':
            self.node_dyn = self.setNewFluidProperty(self.node_fluid, 'dynamic_diffusion')
            self.nodeList = (self.node_density, self.node_viscosity,
                             self.node_heat, self.node_dyn)

        elif self.node_gas['model'] != None and self.node_gas['model'] != 'off':
            self.node_dyn = self.setNewFluidProperty(self.node_fluid, 'dynamic_diffusion')
            self.nodeList = (self.node_density, self.node_viscosity,
                             self.node_heat, self.node_dyn)

        elif self.node_comp['model'] != None and self.node_comp['model'] != 'off':
            self.node_vol_visc  = self.setNewFluidProperty(self.node_fluid, 'volumic_viscosity')
            self.node_dyn = self.setNewFluidProperty(self.node_fluid, 'dynamic_diffusion')
            self.nodeList = (self.node_density, self.node_viscosity,
                             self.node_heat, self.node_vol_visc, self.node_dyn)
        else:
            self.node_cond      = self.setNewFluidProperty(self.node_fluid, 'thermal_conductivity')
            self.nodeList = (self.node_density, self.node_viscosity,
                             self.node_heat, self.node_cond)

        for node in self.nodeList:
            if node['name'] == name:
                return node


    def defaultFluidCharacteristicsValues(self):
        """
        Return in a dictionnary which contains default values.
        (also called by CoalCombustionModel)
        """
        default = {}

        #Initial values for properties: 20 Celsius degrees air at atmospheric pressure

        default['density']              = 1.17862
        default['molecular_viscosity']  = 1.83e-05
        default['specific_heat']        = 1017.24
        default['thermal_conductivity'] = 0.02495
        default['dynamic_diffusion']    = 0.01
        default['volumic_viscosity']    = 1.83e-05

        return default


    @Variables.noUndo
    def getThermalModel(self):
        """
        Return node and model of choosen thermophysical model
        """
        modelList = []
        node1 = self.node_models.xmlGetNode('gas_combustion',    'model')
        node2 = self.node_models.xmlGetNode('solid_fuels',       'model')
        node3 = self.node_models.xmlGetNode('joule_effect',      'model')
        node4 = self.node_models.xmlGetNode('thermal_scalar',    'model')
        node5 = self.node_models.xmlGetNode('atmospheric_flows', 'model')

        for node in (node1, node2, node3, node4, node5):
            if node:
                if node['model'] == "":
                    node['model'] = "off"
                if node['model'] != 'off':
                    modelList.append(node['model'])
                    nodeThermal = node

        if len(modelList) > 1:
            raise ValueError("Erreur de model thermique dans le fichier XML")
        elif modelList == []:
            modelList.append('off')
            nodeThermal = None

        return nodeThermal, modelList[0]


    @Variables.noUndo
    def getThermoPhysicalModel(self):
        """
        Return values of attribute "model" of all thermophysical model nodes.
        (also called by NumericalParamGlobalView and TimeStepView)
        """
        d = {}
        d['joule_effect']      = 'off'
        d['gas_combustion']    = 'off'
        d['solid_fuels']       = 'off'
        d['thermal_scalar']    = 'off'
        d['atmospheric_flows'] = 'off'

        node, model = self.getThermalModel()
        if node:
            d[node.el.tagName] = model

        return d['atmospheric_flows'], \
               d['joule_effect'],      \
               d['thermal_scalar'],    \
               d['gas_combustion'],    \
               d['solid_fuels']


    @Variables.noUndo
    def getInitialValue(self, tag):
        """
        Return initial value of the markup tag : 'density', or
        'molecular_viscosity', or 'specific_heat'or 'thermal_conductivity'
        """
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity', 'dynamic_diffusion'))
        node = self.node_fluid.xmlGetNode('property', name=tag)
        pp = node.xmlGetDouble('initial_value')
        if pp == None:
            pp = self.defaultFluidCharacteristicsValues()[tag]
            self.setInitialValue(tag, pp)
        return pp


    @Variables.undoLocal
    def setInitialValue(self, tag, val):
        """
        Put initial value for the markup tag : 'density', or
        'molecular_viscosity', or 'specific_heat'or 'thermal_conductivity'
        """
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity', 'dynamic_diffusion'))
        self.isGreater(val, 0.)
        node = self.node_fluid.xmlGetNode('property', name=tag)
        node.xmlSetData('initial_value', val)


    @Variables.noUndo
    def getInitialValueDensity(self):
        """Return initial value of density"""
        return self.getInitialValue('density')


    @Variables.undoLocal
    def setInitialValueDensity(self, val):
        """Put initial value for density"""
        self.setInitialValue('density', val)


    @Variables.noUndo
    def getInitialValueViscosity(self):
        """Return initial value of viscosity"""
        return self.getInitialValue('molecular_viscosity')


    @Variables.undoLocal
    def setInitialValueViscosity(self, val):
        """Put initial value for viscosity"""
        self.setInitialValue('molecular_viscosity', val)


    @Variables.noUndo
    def getInitialValueVolumicViscosity(self):
        """Return initial value of volumic viscosity"""
        return self.getInitialValue('volumic_viscosity')


    @Variables.undoLocal
    def setInitialValueVolumicViscosity(self, val):
        """Put initial value for volumic viscosity"""
        self.setInitialValue('volumic_viscosity', val)


    @Variables.noUndo
    def getInitialValueHeat(self):
        """Return initial value of specific heat"""
        return self.getInitialValue('specific_heat')


    @Variables.undoLocal
    def setInitialValueHeat(self, val):
        """Put initial value for specific heat"""
        self.setInitialValue('specific_heat', val)


    @Variables.noUndo
    def getInitialValueCond(self):
        """Return initial value of conductivity"""
        return self.getInitialValue('thermal_conductivity')


    @Variables.undoLocal
    def setInitialValueCond(self, val):
        """Put initial value for conductivity"""
        self.setInitialValue('thermal_conductivity', val)


    @Variables.noUndo
    def getInitialValueDyn(self):
        """Return initial value of conductivity"""
        return self.getInitialValue('dynamic_diffusion')


    @Variables.undoLocal
    def setInitialValueDyn(self, val):
        """Put initial value for conductivity"""
        self.setInitialValue('dynamic_diffusion', val)


    @Variables.noUndo
    def getFormula(self, tag):
        """
        Return a formula for I{tag} 'density', 'molecular_viscosity',
        'specific_heat' or 'thermal_conductivity'
        """
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity'))
        node = self.node_fluid.xmlGetNode('property', name=tag)
        formula = node.xmlGetString('formula')
        if not formula:
            formula = self.getDefaultFormula(tag)
            self.setFormula(tag, formula)
        return formula


    @Variables.noUndo
    def getDefaultFormula(self, tag):
        """
        Return default formula
        """
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity'))
        if tag == "density":
            formula = "rho ="
        elif tag == "molecular_viscosity":
            formula = "mu ="
        elif tag == "specific_heat":
            formula = "cp ="
        elif tag == "volumic_viscosity":
            formula = "Viscv ="
        elif tag == "thermal_conductivity":
            formula = "lambda ="

        return formula


    @Variables.undoLocal
    def setFormula(self, tag, str):
        """
        Gives a formula for 'density', 'molecular_viscosity',
        'specific_heat'or 'thermal_conductivity'
        """
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity'))
        node = self.node_fluid.xmlGetNode('property', name=tag)
        node.xmlSetData('formula', str)


    @Variables.noUndo
    def getPropertyMode(self, tag):
        """Return choice of node I{tag}. Choice is constant or variable"""
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity'))
        node = self.__nodeFromTag(tag)
        c = node['choice']
        self.isInList(c, ('constant', 'user_law', 'variable'))
        return c


    @Variables.undoGlobal
    def setPropertyMode(self, tag, choice):
        """Put choice in xml file's node I{tag}"""
        self.isInList(tag, ('density', 'molecular_viscosity',
                            'specific_heat', 'thermal_conductivity',
                            'volumic_viscosity'))
        self.isInList(choice, ('constant', 'user_law', 'variable'))

        node = self.__nodeFromTag(tag)
        node['choice'] = choice

        if choice == 'constant':
            node.xmlInitNode('listing_printing')['status'] = 'off'
            node.xmlInitNode('postprocessing_recording')['status'] = 'off'

            if tag == 'density':
                from Pages.TimeStepModel import TimeStepModel
                TimeStepModel(self.case).RemoveThermalTimeStepNode()
                del TimeStepModel
        else:
            if node.xmlGetNode('listing_printing'):
                node.xmlRemoveChild('listing_printing')
            if node.xmlGetNode('postprocessing_recording'):
                node.xmlRemoveChild('postprocessing_recording')


##    def RemoveThermoConductNode(self):
##        """Remove balise property for thermal_conductivity"""
##        self.node_fluid.xmlRemoveChild('property', name='thermal_conductivity')



#-------------------------------------------------------------------------------
# FluidCharacteristicsModel test case
#-------------------------------------------------------------------------------


class FluidCharacteristicsModelTestCase(ModelTest):
    """
    """
    def checkFluidCharacteristicsInstantiation(self):
        """Check whether the FluidCaracteristicsModel class could be instantiated"""
        model = None
        model = FluidCharacteristicsModel(self.case)
        assert model != None, 'Could not instantiate FluidCaracteristicsModel'

    def checkGetThermoPhysicalModel(self):
        """Check whether thermal physical models could be get"""
        mdl = FluidCharacteristicsModel(self.case)
        from Pages.ThermalScalarModel import ThermalScalarModel
        ThermalScalarModel(self.case).setThermalModel('temperature_celsius')
        del ThermalScalarModel
        assert mdl.getThermoPhysicalModel() == ('off', 'off', 'temperature_celsius', 'off', 'off'),\
        'Could not get thermophysical models in FluidCaracteristicsModel'

    def checkSetandGetInitialValue(self):
        """Check whether the initial value for the properties could be set and get"""
        mdl = FluidCharacteristicsModel(self.case)
        mdl.setInitialValue('density', 123.0)
        mdl.setInitialValue('molecular_viscosity', 1.5e-5)
        mdl.setInitialValue('specific_heat', 1212)
        mdl.setInitialValue('thermal_conductivity', 0.04)
        doc = '''<fluid_properties>
                    <property choice="constant" label="Density" name="density">
                        <listing_printing status="off"/>
                        <postprocessing_recording status="off"/>
                        <initial_value>123</initial_value>
                    </property>
                    <property choice="constant" label="LamVisc" name="molecular_viscosity">
                        <listing_printing status="off"/>
                        <postprocessing_recording status="off"/>
                        <initial_value>1.5e-05</initial_value>
                    </property>
                    <property choice="constant" label="Sp. heat" name="specific_heat">
                        <listing_printing status="off"/>
                        <postprocessing_recording status="off"/>
                        <initial_value>1212</initial_value>
                    </property>
                    <property choice="constant" label="Th. cond" name="thermal_conductivity">
                        <listing_printing status="off"/>
                        <postprocessing_recording status="off"/>
                        <initial_value>0.04</initial_value>
                    </property>
                 </fluid_properties>'''
        assert mdl.node_fluid == self.xmlNodeFromString(doc),\
        'Could not set initial value for properties in FluidCharacteristicsModel model'
        assert mdl.getInitialValue('specific_heat') == 1212.,\
         'Could not get initial value for properties in FluidCharacteristicsModel model'

    def checkSetandGetInitialValueDensity(self):
        """Check whether the initial value for density could be set and get"""
        mdl = FluidCharacteristicsModel(self.case)
        mdl.setInitialValueDensity(89.98)
        doc = '''<property choice="constant" label="Density" name="density">
                    <listing_printing status="off"/>
                    <postprocessing_recording status="off"/>
                    <initial_value>89.98</initial_value>
                 </property>'''
        assert mdl.node_density == self.xmlNodeFromString(doc),\
        'Could not set initial value of density'
        assert mdl.getInitialValueDensity() == 89.98,\
        'Could not get initial value of density'

    def checkSetandGetInitialValueViscosity(self):
        """Check whether the initial value for molecular_viscosity could be set and get"""
        mdl = FluidCharacteristicsModel(self.case)
        mdl.setInitialValueViscosity(1.2e-4)
        doc = '''<property choice="constant" label="LamVisc" name="molecular_viscosity">
                    <listing_printing status="off"/>
                    <postprocessing_recording status="off"/>
                    <initial_value>1.2e-4</initial_value>
                 </property>'''
        assert mdl.node_viscosity == self.xmlNodeFromString(doc),\
        'Could not set initial value of molecular_viscosity'
        assert mdl.getInitialValueViscosity() == 1.2e-4,\
        'Could not get initial value of molecular_viscosity'

    def checkSetandGetInitialValueHeat(self):
        """Check whether the initial value for specific_heat could be set and get"""
        mdl = FluidCharacteristicsModel(self.case)
        mdl.setInitialValueHeat(456.9)
        doc = '''<property choice="constant" label="Sp. heat" name="specific_heat">
                    <listing_printing status="off"/>
                    <postprocessing_recording status="off"/>
                    <initial_value>456.9</initial_value>
                 </property>'''
        assert mdl.node_heat == self.xmlNodeFromString(doc),\
        'Could not set initial value of specific_heat'
        assert mdl.getInitialValueHeat() == 456.9,\
        'Could not get initial value of specific_heat'

    def checkSetandGetInitialValueCond(self):
        """Check whether the initial value for thermal_conductivity could be set and get"""
        mdl = FluidCharacteristicsModel(self.case)
        mdl.setInitialValueCond(456.9)
        doc = '''<property choice="constant" label="Th. cond" name="thermal_conductivity">
                    <listing_printing status="off"/>
                    <postprocessing_recording status="off"/>
                    <initial_value>456.9</initial_value>
                 </property>'''
        assert mdl.node_cond == self.xmlNodeFromString(doc),\
        'Could not set initial value of thermal_conductivity'
        assert mdl.getInitialValueCond() == 456.9,\
        'Could not get initial value of thermal_conductivity'

    def checkSetandGetPropertyMode(self):
        """Check whether choice constant or variable could be set and get"""
        mdl = FluidCharacteristicsModel(self.case)
        mdl.setPropertyMode('density', 'variable')
        doc = '''<property choice="variable" label="Density" name="density">
                    <initial_value>1.17862</initial_value>
                 </property>'''
        assert mdl.node_density == self.xmlNodeFromString(doc),\
        'Could not set choice constant or variable for property'
        assert mdl.getPropertyMode('density') == 'variable',\
        'Could not get choice constant or variable for property'

        mdl.setPropertyMode('density', 'constant')
        doc2 = '''<property choice="constant" label="Density" name="density">
                    <initial_value>1.17862</initial_value>
                    <listing_printing status="off"/>
                    <postprocessing_recording status="off"/>
                 </property>'''
        assert mdl.node_density == self.xmlNodeFromString(doc2),\
        'Could not set listing and recording status for property and remove this nodes'

##    def checkRemoveThermoConductNode(self):
##        """Check whether node thermal conductivity could be removed"""
##        mdl = FluidCharacteristicsModel(self.case)
##        mdl.setPropertyMode('density', 'variable')
##        mdl.setPropertyMode('molecular_viscosity', 'variable')
##        mdl.setPropertyMode('specific_heat', 'variable')
##        mdl.RemoveThermoConductNode()
##        doc = '''<fluid_properties>
##                    <property choice="variable" label="Density" name="density">
##                        <initial_value>1.17862</initial_value>
##                    </property>
##                    <property choice="variable" label="LamVisc" name="molecular_viscosity">
##                        <initial_value>1.83e-05</initial_value>
##                    </property>
##                    <property choice="variable" label="Sp. heat" name="specific_heat">
##                        <initial_value>1017.24</initial_value>
##                    </property>
##                 </fluid_properties>'''
##        assert mdl.node_fluid == self.xmlNodeFromString(doc),\
##        'Could not remove thermal_conductivity node'


def suite():
    testSuite = unittest.makeSuite(FluidCharacteristicsModelTestCase, "check")
    return testSuite


def runTest():
    print(__file__)
    runner = unittest.TextTestRunner()
    runner.run(suite())


#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
