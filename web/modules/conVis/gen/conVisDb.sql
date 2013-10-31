-- phpMyAdmin SQL Dump
-- version 4.0.3
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jun 11, 2013 at 09:39 AM
-- Server version: 5.5.31-MariaDB-log
-- PHP Version: 5.4.16

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `conVisDb`
--
CREATE DATABASE IF NOT EXISTS `conVisDb` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE `conVisDb`;

-- --------------------------------------------------------

--
-- Table structure for table `apps`
--

CREATE TABLE IF NOT EXISTS `apps` (
  `appId` int(11) NOT NULL,
  `appName` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `banList`
--

CREATE TABLE IF NOT EXISTS `banList` (
  `userId` varchar(50) NOT NULL,
  `appId` int(50) NOT NULL,
  `hostDomain` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `uaToAppId`
--

CREATE TABLE IF NOT EXISTS `uaToAppId` (
  `userAgentHash` char(64) NOT NULL,
  `userAgent` varchar(10000) NOT NULL,
  `appId` int(50) NOT NULL,
  PRIMARY KEY (`userAgentHash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
