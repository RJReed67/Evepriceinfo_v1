-- phpMyAdmin SQL Dump
-- version 3.5.8.1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Sep 10, 2013 at 03:59 PM
-- Server version: 5.5.32-log
-- PHP Version: 5.4.17

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

--
-- Database: `EvePriceInfo`
--

-- --------------------------------------------------------

--
-- Table structure for table `followers`
--

CREATE TABLE IF NOT EXISTS `followers` (
  `UserKey` bigint(20) NOT NULL AUTO_INCREMENT,
  `TwitchID` varchar(40) NOT NULL,
  `Tokens` int(11) NOT NULL,
  `TTL` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`UserKey`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=305 ;

-- --------------------------------------------------------

--
-- Table structure for table `icerefine`
--

CREATE TABLE IF NOT EXISTS `icerefine` (
  `IceType` varchar(30) NOT NULL,
  `RefineSize` int(11) NOT NULL,
  `Heavy Water` int(11) NOT NULL,
  `Helium Isotopes` int(11) NOT NULL,
  `Hydrogen Isotopes` int(11) NOT NULL,
  `Nitrogen Isotopes` int(11) NOT NULL,
  `Oxygen Isotopes` int(11) NOT NULL,
  `Liquid Ozone` int(11) NOT NULL,
  `Strontium Calthrates` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `refineInfo`
--

CREATE TABLE IF NOT EXISTS `refineInfo` (
  `refineItem` varchar(50) NOT NULL,
  `batchsize` int(11) NOT NULL,
  `Tritanium` int(11) NOT NULL,
  `Pyerite` int(11) NOT NULL,
  `Mexallon` int(11) NOT NULL,
  `Isogen` int(11) NOT NULL,
  `Nocxium` int(11) NOT NULL,
  `Zydrine` int(11) NOT NULL,
  `Megacyte` int(11) NOT NULL,
  `Morphite` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `regionids`
--

CREATE TABLE IF NOT EXISTS `regionids` (
  `RegionID` int(11) NOT NULL,
  `RegionName` varchar(50) NOT NULL,
  PRIMARY KEY (`RegionID`),
  KEY `RegionID` (`RegionID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `systemids`
--

CREATE TABLE IF NOT EXISTS `systemids` (
  `SystemID` int(11) NOT NULL,
  `SystemName` varchar(50) NOT NULL,
  `RegionID` int(11) NOT NULL,
  `Faction` int(11) NOT NULL,
  `Securty` decimal(20,19) NOT NULL,
  `ConstellationID` int(11) NOT NULL,
  `TrueSec` decimal(20,19) NOT NULL,
  PRIMARY KEY (`SystemID`),
  KEY `SystemID` (`SystemID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `typeids`
--

CREATE TABLE IF NOT EXISTS `typeids` (
  `ItemID` int(6) NOT NULL DEFAULT '0',
  `ItemName` varchar(78) DEFAULT NULL,
  `ItemID2` varchar(19) DEFAULT NULL,
  PRIMARY KEY (`ItemID`),
  KEY `ItemID` (`ItemID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
