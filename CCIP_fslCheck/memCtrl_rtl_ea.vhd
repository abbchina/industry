-- **************************************************************************************
-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Memory Controller "memCtrl" unit
-- File name:           memCtrlUnit_rtl_a.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.1
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		First version
-- Date:		2008-11-12
-- **************************************************************************************
-- References:
-- 1. Datasheet ST M95512-R 512Kbit Serial SPI EEPROM
-- 2. Datasheet Numonyx M25P80 8Mbit Serial SPI Flash
-- 3. IS - memCtrl unit in R19/R21 3HAC TBD
-- **************************************************************************************
-- Functional description:
--
-- The purpose is to handle different types of requests issued either by the Mailbox
-- interface unit or the ESM unit. The request implies that memCtrl unit
-- selects on of the three memory devices:
--
-- Flash1 = contains the default firmware image which is loaded at startup
-- Flash2 = used for firmware upgrade
-- EEPROM = used for storing of calibration data etc
--
-- Three different kinds of requests are performed:
-- req1 = start to select a specific flash device selected by "flashToSel"
-- reg2 = start to read out the "ValidFlag" byte from flash2 and verify the contents
-- req3 = start to select either flash 2 or eeprom selected by "memSel"
--
-- Furthermore, one SPI unit is shared by three memories and the SPI
-- interface mapping is done in memCtrl unit.
--
-- flashToSel: 0 = flash1 / 1 = flash2
-- memSel    : 0 = flash2 / 1 = eeprom
--
-- **************************************************************************************
-- changes:
-- 1.1 
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.numeric_std.ALL;

ENTITY memCtrl IS
  PORT(
    rst_n                : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;
    -- ESM:
    flashToSel           : IN  STD_LOGIC;
    startFlashSelect     : IN  STD_LOGIC;
    flashSelectDone      : OUT STD_LOGIC;
    startFlashValidCheck : IN  STD_LOGIC;
    flashValidCheckDone  : OUT STD_LOGIC;
    flashValidFlagOk     : OUT STD_LOGIC;
    -- Mailbox unit:
    mbxIrq               : IN  STD_LOGIC;
    sdoType              : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    rdDataReq            : OUT STD_LOGIC;
    rdAddr               : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    rdData               : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    rdDataValid          : IN  STD_LOGIC;
    wrDataReq            : OUT STD_LOGIC;
    wrAddr               : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    wrData               : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    wrDataBusy           : IN  STD_LOGIC;
    sdoOpCompleted       : OUT STD_LOGIC;
    sdoOpError           : OUT STD_LOGIC;
    sdoOpErrorCode       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    -- External Flip Flop:
    flashSelect          : OUT STD_LOGIC;
    flashSelectMirror    : IN  STD_LOGIC;
    -- Flash SPI interface:
    flashMiso            : IN  STD_LOGIC;
    flashMosi            : OUT STD_LOGIC;
    flashSpiCs_n         : OUT STD_LOGIC;
    flashSpiClk          : OUT STD_LOGIC;
    -- EEPROM SPI interface:    
    eepromMiso           : IN  STD_LOGIC;
    eepromMosi           : OUT STD_LOGIC;
    eepromSpiCs_n        : OUT STD_LOGIC;
    eepromSpiClk         : OUT STD_LOGIC
    );
END memCtrl;

ARCHITECTURE rtl OF memCtrl IS

-------------------------------------------------------------------------------
-- Component instantiations:
-------------------------------------------------------------------------------  

  COMPONENT reqMgr
    PORT(
      rst_n                : IN  STD_LOGIC;
      clk                  : IN  STD_LOGIC;
      -- ESM:
      flashToSel           : IN  STD_LOGIC;
      startFlashSelect     : IN  STD_LOGIC;
      flashSelectDone      : OUT STD_LOGIC;
      startFlashValidCheck : IN  STD_LOGIC;
      flashValidCheckDone  : OUT STD_LOGIC;
      flashValidFlagOk     : OUT STD_LOGIC;
      -- mbxIf:
      startCheckValidFlag  : OUT STD_LOGIC;
      validFlagStatus      : IN  STD_LOGIC;
      validFlagCheckDone   : IN  STD_LOGIC;
      startMemSelect       : IN  STD_LOGIC;
      memSel               : IN  STD_LOGIC;
      memSelectDone        : OUT STD_LOGIC;
      -- External flip flop:
      flashSelect          : OUT STD_LOGIC;
      flashSelectMirror    : IN  STD_LOGIC;
      -- Memory type selection control:
      enableFlashEeprom_n  : OUT STD_LOGIC
      );
  END COMPONENT reqMgr;

  COMPONENT mbxIf
    PORT(
      rst_n               : IN  STD_LOGIC;
      clk                 : IN  STD_LOGIC;
      -- mbx unit:
      mbxIrq              : IN  STD_LOGIC;
      sdoType             : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      rdDataReq           : OUT STD_LOGIC;
      rdAddr              : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      rdData              : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      rdDataValid         : IN  STD_LOGIC;
      wrDataReq           : OUT STD_LOGIC;
      wrAddr              : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      wrData              : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      wrDataBusy          : IN  STD_LOGIC;
      sdoOpError          : OUT STD_LOGIC;
      sdoOpErrorCode      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);      
      -- reqMgr:
      startCheckValidFlag : IN  STD_LOGIC;
      validFlagStatus     : OUT STD_LOGIC;
      validFlagCheckDone  : OUT STD_LOGIC;
      startMemSelect      : OUT STD_LOGIC;
      memSel              : OUT STD_LOGIC;
      memSelectDone       : IN  STD_LOGIC;
      -- SPI unit:
      spiIrq              : OUT STD_LOGIC;
      sdoOpCompleted      : IN  STD_LOGIC;
      -- SPI TX data, i.e. transmitted to SPI
      appData             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      appDataAddr         : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      appDataReq          : IN  STD_LOGIC;
      -- SPI RX data, i.e. received from SPI
      spiData             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      spiDataAddr         : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      spiDataUpd          : IN  STD_LOGIC;
      spiDataDone         : IN  STD_LOGIC;
      spiRdInProgress     : IN  STD_LOGIC
      );
  END COMPONENT mbxIf;
  
  COMPONENT spi
    PORT(
      rst_n           : IN  STD_LOGIC;
      clk             : IN  STD_LOGIC;
      spiIrq          : IN  STD_LOGIC;
      memSel          : IN  STD_LOGIC;
      spiOpCompleted  : OUT STD_LOGIC;
      -- TX data:
      appData         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      appDataAddr     : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      appDataReq      : OUT STD_LOGIC;
      -- RX data:
      spiData         : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      spiDataAddr     : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      spiDataUpd      : OUT STD_LOGIC;
      spiDataDone     : OUT STD_LOGIC;
      spiRdInProgress : OUT STD_LOGIC;
      -- SPI PHY interface:
      miso            : IN  STD_LOGIC;
      mosi            : OUT STD_LOGIC;
      spiCs_n         : OUT STD_LOGIC;
      spiClk          : OUT STD_LOGIC
      );
  END COMPONENT spi;

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------  

  -- Connects regMgr and mbxIf:
  SIGNAL startCheckValidFlag : STD_LOGIC;
  SIGNAL validFlagStatus     : STD_LOGIC;
  SIGNAL validFlagCheckDone  : STD_LOGIC;
  SIGNAL startMemSelect      : STD_LOGIC;
  SIGNAL memSel              : STD_LOGIC;
  SIGNAL memSelectDone       : STD_LOGIC;

  -- Control signals from reqMgr:
  SIGNAL enableFlashEeprom_n : STD_LOGIC;

  -- Connects mbxIf and SPI:  
  SIGNAL spiIrq          : STD_LOGIC;
  SIGNAL spiOpCompleted  : STD_LOGIC;
  SIGNAL appData         : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL appDataAddr     : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL appDataReq      : STD_LOGIC;
  SIGNAL spiData         : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL spiDataAddr     : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL spiDataUpd      : STD_LOGIC;
  SIGNAL spiDataDone     : STD_LOGIC;
  SIGNAL spiRdInProgress : STD_LOGIC;

  -- SPI physical interface:
  SIGNAL miso    : STD_LOGIC;
  SIGNAL mosi    : STD_LOGIC;
  SIGNAL spiClk  : STD_LOGIC;
  SIGNAL spiCs_n : STD_LOGIC;

BEGIN

  reqMgr_i0 : reqMgr
    PORT MAP (
      rst_n                => rst_n,
      clk                  => clk,
      -- ESM:
      flashToSel           => flashToSel,
      startFlashSelect     => startFlashSelect,
      flashSelectDone      => flashSelectDone,
      startFlashValidCheck => startFlashValidCheck,
      flashValidCheckDone  => flashValidCheckDone,
      flashValidFlagOk     => flashValidFlagOk,
      -- mbx if:
      startCheckValidFlag  => startCheckValidFlag,
      validFlagStatus      => validFlagStatus,
      validFlagCheckDone   => validFlagCheckDone,
      startMemSelect       => startMemSelect,
      memSel               => memSel,
      memSelectDone        => memSelectDone,
      -- Flop Flop:      
      flashSelect          => flashSelect,
      flashSelectMirror    => flashSelectMirror,
      -- Memory selection control:
      enableFlashEeprom_n  => enableFlashEeprom_n
      );

  mbxIf_i0 : mbxIf
    PORT MAP (
      rst_n               => rst_n,
      clk                 => clk,
      -- mbx unit:
      mbxIrq              => mbxIrq,
      sdoType             => sdoType,
      rdDataReq           => rdDataReq,
      rdAddr              => rdAddr,
      rdData              => rdData,
      rdDataValid         => rdDataValid,
      wrDataReq           => wrDataReq,
      wrAddr              => wrAddr,
      wrData              => wrData,
      wrDataBusy          => wrDataBusy,
      sdoOpError          => sdoOpError,
      sdoOpErrorCode      => sdoOpErrorCode,
      -- reqMgr:
      startCheckValidFlag => startCheckValidFlag,
      validFlagStatus     => validFlagStatus,
      validFlagCheckDone  => validFlagCheckDone,
      startMemSelect      => startMemSelect,
      memSel              => memSel,
      memSelectDone       => memSelectDone,
      -- SPI unit:
      spiIrq              => spiIrq,
      sdoOpCompleted      => spiOpCompleted,
      -- SPI TX data, i.e. transmitted to SPI
      appData             => appData,
      appDataAddr         => appDataAddr,
      appDataReq          => appDataReq,
      -- SPI RX data, i.e. received from SPI
      spiData             => spiData,
      spiDataAddr         => spiDataAddr,
      spiDataUpd          => spiDataUpd,
      spiDataDone         => spiDataDone,
      spiRdInProgress     => spiRdInProgress
      );

  spi_i0 : spi
    PORT MAP (
      rst_n           => rst_n,
      clk             => clk,
      spiIrq          => spiIrq,
      memSel          => memSel,
      spiOpCompleted  => spiOpCompleted,
      -- Read applic data from TX buffer:
      appData         => appData,
      appDataAddr     => appDataAddr,
      appDataReq      => appDataReq,
      -- Write spi data to RX buffer:      
      spiData         => spiData,
      spiDataAddr     => spiDataAddr,
      spiDataUpd      => spiDataUpd,
      spiDataDone     => spiDataDone,
      spiRdInProgress => spiRdInProgress,
      -- SPI PHY interface:
      miso            => miso,
      mosi            => mosi,
      spiCs_n         => spiCs_n,
      spiClk          => spiClk
      );

  
-------------------------------------------------------------------------------
-- Mapping Flash and EEPROM signals
-------------------------------------------------------------------------------
miso <= flashMiso WHEN enableFlashEeprom_n = '1' ELSE eepromMiso;
  
flashMosi <= mosi;
flashSpiClk <= spiClk;
flashSpiCs_n <= spiCs_n WHEN enableFlashEeprom_n = '1' ELSE '1';

eepromMosi <= mosi;
eepromSpiClk <= spiClk;
eepromSpiCs_n <= spiCs_n WHEN enableFlashEeprom_n = '0' ELSE '1';

-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
sdoOpCompleted <= spiOpCompleted;
   
END ARCHITECTURE rtl;

