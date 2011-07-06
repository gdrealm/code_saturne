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
This module defines the lagrangian two phase flow modelling management.

This module contains the following classes and function:
- LagrangianBoundariesModel
- LagrangianBoundariesTestCase
"""


#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------


import sys, unittest, logging


#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------


from Base.Common import *
import Base.Toolbox as Tool
from Base.XMLvariables import Model
from Pages.LagrangianModel import LagrangianModel


#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------


logging.basicConfig()
log = logging.getLogger("LagrangianBoundariesModel")
log.setLevel(Tool.GuiParam.DEBUG)


#-------------------------------------------------------------------------------
# lagrangian model class
#-------------------------------------------------------------------------------


class LagrangianBoundariesModel(Model):
    """
    Manage the input/output markups in the xml doc about Lagrangian module.
    """
    def __init__(self, case):
        """
        Constructor.
        """
        self.case = case
        self.node_boundaries = self.case.root().xmlInitNode('boundary_conditions')
        self.default = self.defaultParticlesBoundaryValues()


    def defaultParticlesBoundaryValues(self):
        """
        Return a dictionnary which contains default values.
        """
        default = {}
        default['particles'] = "inlet"
        default['nbclas'] = 0
        default['number'] = 10
        default['frequency'] = 1
        default['statistical_groups'] = 0.
        default['statistical_weight_choice'] = "prescribed"
        default['statistical_weight'] = 1.0
        default['mass_flow_rate'] = 0.
        default['density'] = 1000.
        default['velocity_choice'] = "fluid"
        default['velocity_norm'] = 0.
        default['velocity_value'] = 0.
        default['temperature_choice'] = "prescribed"
        default['temperature'] = 20.
        default['specific_heat'] = 1400.
        default['emissivity'] = 0.9
        default['diameter_choice'] = "prescribed"
        default['diameter'] = 1.0e-5
        default['diameter_standard_deviation'] = 0.
        default['coal_number'] = 0
        default['coal_temperature'] = 0.
        default['raw_coal_mass_fraction'] = 0.
        default['char_mass_fraction'] = 0.
        return default


    def setBoundaryChoice(self, nature, labelbc, value):
        """
        Update value for the boundary condition. Here we defined the xml nodes
        'self.node_boundary' and 'self.node_particles' used in many functions.
        """
        if nature == "inlet":
            self.isInList(value, ["inlet"])
        elif nature == "outlet":
            self.isInList(value, ["outlet"])
        elif nature == "symmetry":
            self.isInList(value, ["bounce"])
        elif nature == "wall":
            l = [ "inlet", "bounce", "deposit1", "deposit2", "deposit3", "depositfa"]
            #if iscoal: l.append("encra")
            self.isInList(value, l)
        self.node_boundary = self.node_boundaries.xmlInitChildNode(nature, label=labelbc)
        self.node_particles = self.node_boundary.xmlInitChildNode('particles', 'choice')
        self.node_particles['choice'] = value
        self.setCurrentBoundaryNode(nature, labelbc)


    def getBoundaryChoice(self, nature, labelbc):
        """
        Return value for the boundary condition.
        """
        default = { "wall" : "deposit1", "inlet" : "inlet",
                    "outlet" : "outlet", "symmetry" : "bounce"}
        self.setCurrentBoundaryNode(nature, labelbc)
        if self.node_particles:
            val = self.node_particles['choice']
            if val == None or val == "":
                val = default[nature]
                self.setBoundaryChoice(nature, labelbc, val)
        return val


    def setCurrentBoundaryNode(self, nature, labelbc):
        """
        Update the current boundary node.
        """
        self.node_boundary = self.node_boundaries.xmlInitChildNode(nature, label=labelbc)
        self.node_particles = self.node_boundary.xmlInitChildNode('particles', 'choice')


    def newClassNode(self):
        """
        Add a new 'class' node with child nodes.
        """
        node_class = self.node_particles.xmlAddChild('class')
        node_class.xmlSetData('number', self.default['number'])
        node_class.xmlSetData('frequency', self.default['frequency'])
        node_class.xmlSetData('statistical_groups', self.default['statistical_groups'])
        node_class.xmlSetData('mass_flow_rate', self.default['mass_flow_rate'])
        node_class.xmlSetData('density', self.default['density'])

        node_class.xmlInitChildNode('statitical_weight', choice=self.default['statistical_weight_choice'])
        node_class.xmlSetData('statitical_weight', self.default['statistical_weight'])

        node_class.xmlInitChildNode('velocity', choice=self.default['velocity_choice'])
        #node_class.xmlSetData('', self.default[''])

        node_class.xmlInitChildNode('diameter', choice=self.default['diameter_choice'])
        node_class.xmlSetData('diameter', self.default['diameter'])
        node_class.xmlSetData('diameter_standard_deviation', self.default['diameter_standard_deviation'])

        node_class.xmlInitChildNode('temperature', choice=self.default['temperature_choice'])
        node_class.xmlSetData('temperature', self.default['temperature'])

##         node_class.xmlSetData('specific_heat', self.default['specific_heat'])
##         node_class.xmlSetData('emissivity', self.default['emissivity'])
##         node_class.xmlSetData('coal_number', self.default['coal_number'])
##         node_class.xmlSetData('raw_coal_mass_fraction', self.default['raw_coal_mass_fraction'])
##         node_class.xmlSetData('char_mass_fraction', self.default['char_mass_fraction'])


    def setNumberOfClassesValue(self, labelbc, value):
        """
        Update the number of classes. Create or delete nodes if necessary.
        """
        self.isInt(value)
        self.isGreaterOrEqual(value, 0)
        node_list = self.node_particles.xmlGetChildNodeList('class')
        nnodes = len(node_list)
        if value > nnodes:
            for i in range(value-nnodes):
                self.newClassNode()
        else:
            for i in range(nnodes-value):
                node_list[-1].xmlRemoveNode()
            # redefine self.node_class
            self.setCurrentClassNode(labelbc, value)


    def getNumberOfClassesValue(self, labelbc):
        """
        Return the number of classes.
        """
        node_list = self.node_particles.xmlGetChildNodeList('class')
        value = len(node_list)
        if value == None:
            value = self.defaultParticlesBoundaryValues()['nbclas']
            self.setNumberOfClassesValue(labelbc, value)
        return value


    def setCurrentClassNode(self, labelbc, iclass):
        """
        Update the current class node.
        """
        choice = self.node_particles['choice']
        self.isInList(choice, ["inlet"])
        self.isInt(iclass)
        self.node_class = None
        nodes_list = self.node_particles.xmlGetChildNodeList('class')
        if nodes_list:
            nnodes = len(nodes_list)
            self.isLowerOrEqual(iclass, nnodes)
            self.node_class = nodes_list[iclass-1]


    def setNumberOfParticulesInClassValue(self, label, iclass, value):
        """
        Update the number of particles in a class.
        """
        self.isInt(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('number', value)


    def getNumberOfParticulesInClassValue(self, label, iclass):
        """
        Return the number of particles in a class.
        """
        value = self.node_class.xmlGetInt('number')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['number']
            self.setNumberOfParticulesInZoneValue(label, iclass,value)
        return value


    def setInjectionFrequencyValue(self, label, iclass, value):
        """
        Update the injection frequency.
        """
        self.isInt(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('frequency', value)


    def getInjectionFrequencyValue(self, label, iclass):
        """
        Return the injection frequency.
        """
        value = self.node_class.xmlGetInt('frequency')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['frequency']
            self.setInjectionFrequencyValue(label, iclass, value)
        return value


    def setParticleGroupNumberValue(self, label, iclass, value):
        """
        Update the group number of the particle.
        """
        self.isInt(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('statistical_groups', value)


    def getParticleGroupNumberValue(self, label, iclass):
        """
        Return the group number of the particle.
        """
        value = self.node_class.xmlGetInt('statistical_groups')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['statistical_groups']
            self.setParticleGroupNumberValue(label, iclass, value)
        return value


    def setMassFlowRateValue(self, label, iclass, value):
        """
        Update the mass flow rate value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('mass_flow_rate', value)


    def getMassFlowRateValue(self, label, iclass):
        """
        Return the mass flow rate value.
        """
        value = self.node_class.xmlGetDouble('mass_flow_rate')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['mass_flow_rate']
            self.setMassFlowRateValue(label, iclass, value)
        return value


    def setStatisticalWeightChoice(self, label, iclass, value):
        """
        Update the condition on statistical weight.
        """
        self.isInList(value, ["rate", "prescribed", "subroutine"])
        node = self.node_class.xmlInitChildNode('statistical_weight', 'choice')
        node['choice'] = value


    def getStatisticalWeightChoice(self, label, iclass):
        """
        Return the condition on statistical weight.
        """
        node = self.node_class.xmlInitChildNode('statistical_weight', 'choice')
        if node:
            val = node['choice']
            if val == None or val == "":
                val = self.defaultParticlesBoundaryValues()['statistical_weight_choice']
                self.setStatisticalWeightChoice(label, iclass, val)
        return val


    def setStatisticalWeightValue(self, label, iclass, value):
        """
        Update the statistical weight value.
        """
        self.isFloat(value)
        self.isGreater(value, 0)
        self.node_class.xmlSetData('statistical_weight', value)


    def getStatisticalWeightValue(self, label, iclass):
        """
        Return the statistical weight value.
        """
        value = self.node_class.xmlGetDouble('statistical_weight')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['statistical_weight']
            self.setStatisticalWeightValue(label, iclass, value)
        return value


    def setDensityValue(self, label, iclass, value):
        """
        Update the density value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('density', value)


    def getDensityValue(self, label, iclass):
        """
        Return the density value.
        """
        value = self.node_class.xmlGetDouble('density')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['density']
            self.setDensityValue(label, iclass, value)
        return value


    def setVelocityChoice(self, label, iclass, choice):
        """
        Update the condition on velocity.
        """
        self.isInList(choice, ["fluid", "components", "norm", "subroutine"])
        node_velocity = self.node_class.xmlInitChildNode('velocity', 'choice')
        node_velocity['choice'] = choice
        if choice in ["fluid", "norm", "subroutine"]:
            node_velocity.xmlRemoveChild('velocity_x')
            node_velocity.xmlRemoveChild('velocity_y')
            node_velocity.xmlRemoveChild('velocity_z')
        elif choice in ["fluid", "components", "subroutine"]:
            node_velocity.xmlRemoveChild('norm')


    def getVelocityChoice(self, label, iclass):
        """
        Return the condition on velocity.
        """
        node = self.node_class.xmlInitChildNode('velocity', 'choice')
        if node:
            val = node['choice']
            if val == None:
                val = self.defaultParticlesBoundaryValues()['velocity_choice']
                self.setVelocityChoice(val)
        return val


    def setVelocityNormValue(self, label, iclass, value):
        """
        Update the velocity norm.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0.)
        node_velocity = self.node_class.xmlInitChildNode('velocity', choice="norm")
        choice = node_velocity['choice']
        self.isInList(choice, ["norm"])
        node_velocity.xmlSetData('norm', value)


    def getVelocityNormValue(self, label, iclass):
        """
        Return the velocity norm.
        """
        node_velocity = self.node_class.xmlInitChildNode('velocity', choice="norm")
        value = node_velocity.xmlGetDouble('norm')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['velocity_norm']
            self.setVelocityNormValue(label, iclass, value)
        return value


    def setVelocityDirectionValue(self, label, iclass, idir, value):
        """
        Update the velocity value in the given direction.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0.)
        node_velocity = self.node_class.xmlInitChildNode('velocity', choice="components")
        choice = node_velocity['choice']
        self.isInList(choice, ["components"])
        node_velocity.xmlSetData('velocity_' + idir, value)


    def getVelocityDirectionValue(self, label, iclass, idir):
        """
        Return the velocity value in the given direction.
        """
        node_velocity = self.node_class.xmlInitChildNode('velocity', choice="components")
        value = self.node_class.xmlGetDouble('velocity_' + idir)
        if value == None:
            value = self.defaultParticlesBoundaryValues()['velocity_value']
            self.setVelocityDirectionValue(label, iclass, idir, value)
        return value


    def setTemperatureChoice(self, label, iclass, value):
        """
        Update the condition on temperature.
        """
        self.isInList(value, ["prescribed", "subroutine"])
        node = self.node_class.xmlInitChildNode('temperature', 'choice')
        node['choice'] = value


    def getTemperatureChoice(self, label, iclass):
        """
        Return the condition on temperature.
        """
        node = self.node_class.xmlInitChildNode('temperature', 'choice')
        if node:
            val = node['choice']
            if val == None:
                val = self.defaultParticlesBoundaryValues()['temperature_choice']
                self.setTemperatureChoice(label, iclass, val)
        return val


    def setTemperatureValue(self, label, iclass, value):
        """
        Update the temperature value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('temperature', value)


    def getTemperatureValue(self, label, iclass):
        """
        Return the temperature value.
        """
        value = self.node_class.xmlGetDouble('temperature')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['temperature']
            self.setTemperatureValue(label, iclass, value)
        return value


    def setSpecificHeatValue(self, label, iclass, value):
        """
        Update the specific heat value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('specific_heat', value)


    def getSpecificHeatValue(self, label, iclass):
        """
        Return the specific heat value.
        """
        value = self.node_class.xmlGetDouble('specific_heat')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['specific_heat']
            self.setSpecificHeatValue(label, iclass, value)
        return value


    def setEmissivityValue(self, label, iclass, value):
        """
        Update the emissivity value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('emissivity', value)


    def getEmissivityValue(self, label, iclass):
        """
        Return the emissivity value.
        """
        value = self.node_class.xmlGetDouble('emissivity')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['emissivity']
            self.setEmissivityValue(label, iclass, value)
        return value


    def setDiameterChoice(self, label, iclass, value):
        """
        Update the condition on the particle diameter.
        """
        self.isInList(value, ["prescribed", "subroutine"])
        node = self.node_class.xmlInitChildNode('diameter', 'choice')
        node['choice'] = value


    def getDiameterChoice(self, label, iclass):
        """
        Return the condition on the particle diameter.
        """
        node = self.node_class.xmlInitChildNode('diameter', 'choice')
        if node:
            val = node['choice']
            if val == None:
                val = self.defaultParticlesBoundaryValues()['diameter_choice']
                self.setDiameterChoice(label, iclass, val)
        return val


    def setDiameterValue(self, label, iclass, value):
        """
        Update the particle diameter value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('diameter', value)


    def getDiameterValue(self, label, iclass):
        """
        Return the particle diameter value.
        """
        value = self.node_class.xmlGetDouble('diameter')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['diameter']
            self.setDiameterValue(label, iclass, value)
        return value


    def setDiameterVarianceValue(self, label, iclass, value):
        """
        Update the particle diameter variance value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('diameter_standard_deviation', value)


    def getDiameterVarianceValue(self, label, iclass):
        """
        Return the particle diameter variance value.
        """
        value = self.node_class.xmlGetDouble('diameter_standard_deviation')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['diameter_standard_deviation']
            self.setDiameterVarianceValue(label, iclass, value)
        return value


    def setCoalNumberValue(self, label, iclass, value):
        """
        Update the coal number of the particle.
        """
        self.isInt(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('coal_number', value)


    def getCoalNumberValue(self, label, iclass):
        """
        Return the coal number of the particle.
        """
        value = self.node_class.xmlGetInt('coal_number')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['coal_number']
            self.setCoalNumberValue(label, iclass, value)
        return value


    def setCoalTemperatureValue(self, label, iclass, value):
        """
        Update the coal temperature.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('coal_temperature', value)


    def getCoalTemperatureValue(self, label, iclass):
        """
        Return the coal temperature.
        """
        value = self.node_class.xmlGetDouble('coal_temperature')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['coal_temperature']
            self.setCoalTemperatureValue(label, iclass, value)
        return value


    def setCoalMassValue(self, label, iclass, value):
        """
        Update the coal mass value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('raw_coal_mass_fraction', value)


    def getCoalMassValue(self, label, iclass):
        """
        Return the coal mass value.
        """
        value = self.node_class.xmlGetDouble('raw_coal_mass_fraction')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['raw_coal_mass_fraction']
            self.setCoalMassValue(label, iclass, value)
        return value


    def setCokeMassValue(self, label, iclass, value):
        """
        Update the coke mass value.
        """
        self.isFloat(value)
        self.isGreaterOrEqual(value, 0)
        self.node_class.xmlSetData('char_mass_fraction', value)


    def getCokeMassValue(self, label, iclass):
        """
        Return the coke mass value.
        """
        value = self.node_class.xmlGetDouble('char_mass_fraction')
        if value == None:
            value = self.defaultParticlesBoundaryValues()['char_mass_fraction']
            self.setCokeMassValue(label, iclass, svalue)
        return value


#-------------------------------------------------------------------------------
# LagrangianBoundaries test case
#-------------------------------------------------------------------------------


class LagrangianBoundariesTestCase(unittest.TestCase):
    """
    """
    def setUp(self):
        """
        This method is executed before all "check" methods.
        """
        from Base.XMLengine import Case
        from Base.XMLinitialize import XMLinit
        self.case = Case()
        XMLinit(self.case)


    def tearDown(self):
        """
        This method is executed after all "check" methods.
        """
        del self.case


    def checkLagrangianBoundariesInstantiation(self):
        """
        Check whether the LagrangianBoundariesModel class could be instantiated
        """
        model = None
        model = LagrangianBoundariesModel(self.case)

        assert model != None, 'Could not instantiate LagrangianBoundariesModel'


    def checkLagrangianBoundariesDefaultValues(self):
        """
        Check the default values
        """
        model = LagrangianBoundariesModel(self.case)
        doc = """"""

        assert model.node_output == self.xmlNodeFromString(doc),\
               'Could not get default values for model'


def suite():
    testSuite = unittest.makeSuite(LagrangianBoundariesTestCase, "check")
    return testSuite


def runTest():
    print("LagrangianBoundariesTestCase TODO*********.")
    runner = unittest.TextTestRunner()
    runner.run(suite())


#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
