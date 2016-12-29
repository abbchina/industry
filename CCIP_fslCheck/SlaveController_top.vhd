-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Slave Controller Module top entity
-- File name:           puc_sc/SlaveController_top.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.01
-- Prepared by:         CNABB/CRC Ye Zhang
-- Status:              Edited
-- Date:                2009-09-27
-- **************************************************************************************
-- Related files:       puc_top/puc_ip_top.vhd
--                      sc_dpm/sc_dpm.vhd
--                      puc_sc/supervision.vhd
--                      puc_sc/slaveController.vhd
--                      puc_sc/ESM.vhd
--                      puc_sc/cyclical.vhd
--                      puc_sc/sdo_adapter.vhd
--                      puc_sc/fwInfo.vhd
--                      puc_sc/cfgUnit_rtl_ea.vhd
--                      puc_sc/memCtrl_rtl_ea.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- This is the top module for the IP core applications. It demuxes and muxes the 
-- comunication DPM signals to and from the slave application (SlaveController, Cyclical 
-- and ESM) modules respectively.
-- 
-- **************************************************************************************
-- Revision 0.00 - 090927, SEROP/PRCB Björn Nyqvist
-- Copied from SlaveController_top.vhdl (Revision 0.7).
-- **************************************************************************************
-- Revision 0.01 - 090927, CNABB/Ye Zhang
-- Revised Slave Controller top entity.
-- * Removed pdi marks. 
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY SlaveController_top IS
  PORT(
    reset_n                  : IN  STD_LOGIC;
    clk                      : IN  STD_LOGIC;
    -- IRQ ports
    irq_level                : IN  STD_LOGIC;
    irq_synch_pulse          : IN  STD_LOGIC;
    -- DPM ports
	 comm_dpm_web             : OUT STD_LOGIC;
    comm_dpm_dinb            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_doutb           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_addrb           : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    pu_dpm_web               : IN  STD_LOGIC;
    pu_dpm_dinb              : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    pu_dpm_doutb             : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    pu_dpm_addrb             : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
    pu_dpm_clkb              : IN  STD_LOGIC;
    -- Memory ports
    reconfig_n               : OUT STD_LOGIC;
    flashSelect              : OUT STD_LOGIC;
    flashSelectMirror        : IN  STD_LOGIC;
    flashMiso                : IN  STD_LOGIC;
    flashMosi                : OUT STD_LOGIC;
    flashSpiCs_n             : OUT STD_LOGIC;
    flashSpiClk              : OUT STD_LOGIC;
    eepromMiso               : IN  STD_LOGIC;
    eepromMosi               : OUT STD_LOGIC;
    eepromSpiCs_n            : OUT STD_LOGIC;
    eepromSpiClk             : OUT STD_LOGIC;
    -- PU internal ports
    deadTimeInverter1        : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter2        : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter3        : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter4        : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter5        : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter6        : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    puTrigg                  : OUT STD_LOGIC;
    puErrorTrigg             : OUT STD_LOGIC;
    periodicStarted          : OUT STD_LOGIC;
    activeNodes              : OUT STD_LOGIC_VECTOR(6 DOWNTO 1);
    cfgDone                  : OUT STD_LOGIC;
    bleederTurnOnLevel       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederTurnOffLevel      : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederTestLevel         : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcSettleLevel            : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcEngageLevel            : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcDisengageLevel         : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    mainsVACType             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    noOfPhases               : OUT STD_LOGIC;
    wdtTimeout               : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);      
    powerBoardSupplyFail     : IN  STD_LOGIC;
    sampleADCEveryPeriod     : OUT STD_LOGIC;
    onlyIgnoreNodes          : OUT STD_LOGIC;
    cyclical_pu_data_updated : OUT STD_LOGIC;
    pu_fdb_updated           : IN  STD_LOGIC;
    sup_comm_failure         : OUT STD_LOGIC;
    -- Legacy ports
    maxNoOfLostFrames        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    mduProtocolVersion       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    startUpDone              : OUT STD_LOGIC
    );
END SlaveController_top;

ARCHITECTURE rtl OF SlaveController_top IS

  COMPONENT sc_dpm
    PORT(
      addra : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
      addrb : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
      clka  : IN  STD_LOGIC;
      clkb  : IN  STD_LOGIC;
      dina  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      dinb  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      wea   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
      web   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0)
      );
  END COMPONENT;

  COMPONENT supervision
    PORT(
      reset_n             : IN  STD_LOGIC;
      clk                 : IN  STD_LOGIC;
      -- IRQ signals
      irq_synch_pulse     : IN  STD_LOGIC;
      -- SC internal signals
      comm_error          : OUT STD_LOGIC;
      comm_failure        : OUT STD_LOGIC;
      lostFrames	        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
      resetCommFailure	  : IN  STD_LOGIC;
      periodicStarted	  : IN  STD_LOGIC;
      -- ConfigUnit signals
      wdtTimeout          : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      wdtTimeoutInterval  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      maxNoOfLostFrames   : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
  END COMPONENT supervision;

  COMPONENT slaveController
    PORT(
      reset_n                : IN  STD_LOGIC;
      clk                    : IN  STD_LOGIC;
      -- IRQ signals
      eventTrigg             : IN  STD_LOGIC;
      irqLevel               : IN  STD_LOGIC;
      -- DPM signals
      comm_dpm_web           : OUT STD_LOGIC;
      comm_dpm_dinb          : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_doutb         : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_addrb         : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      ctrl_dpm               : OUT STD_LOGIC;
		-- ESM internal signals
      ESM_start              : OUT STD_LOGIC;
      ESM_done               : IN  STD_LOGIC;
      alStatus		           : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      alControl		        : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      startUpDone            : IN  STD_LOGIC;
		-- SDO internal signals
      sdoWriteEvent	        : OUT STD_LOGIC;
      sdoReadEvent	        : OUT STD_LOGIC;
      SDO_done    	        : IN  STD_LOGIC;
		-- Cyclical internal signals
      cyclical_start         : OUT STD_LOGIC;
      cyclical_done          : IN  STD_LOGIC;
      validFrame             : OUT STD_LOGIC;
		-- Supervision internal signals
      errorTrigg             : IN  STD_LOGIC;
      commFailure            : IN  STD_LOGIC;
      lostFrames             : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      resetCommFailure       : OUT STD_LOGIC;
      periodicStarted        : OUT STD_LOGIC;
      -- PU internal ports
      activeNodes            : OUT STD_LOGIC_VECTOR(6 DOWNTO 1);
      onlyIgnoreNodes        : OUT STD_LOGIC;
      puTrigg                : OUT STD_LOGIC;
      puErrorTrigg           : OUT STD_LOGIC;      
      sampleADCEveryPeriod   : OUT STD_LOGIC;
      powerBoardSupplyFail   : IN  STD_LOGIC
      );
  END COMPONENT;

  COMPONENT ESM
    PORT (
      reset_n              : IN  STD_LOGIC;
      clk                  : IN  STD_LOGIC;
      -- DPM signals
		comm_dpm_web         : OUT STD_LOGIC;
      comm_dpm_dinb        : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      comm_dpm_doutb       : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
      comm_dpm_addrb       : OUT STD_LOGIC_VECTOR (5 DOWNTO 0);
      ctrl_dpm             : OUT STD_LOGIC;
      -- SC internal signals
		start                : IN  STD_LOGIC;
      done                 : OUT STD_LOGIC;
      alStatus             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      alControl            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      startUpDone          : OUT STD_LOGIC;
      -- Memory signals
		reconfig_n           : OUT STD_LOGIC;
      flashSelectMirror    : IN  STD_LOGIC;
      flashToSel           : OUT STD_LOGIC;
      startFlashSelect     : OUT STD_LOGIC;
      flashSelectDone      : IN  STD_LOGIC;
      startFlashValidCheck : OUT STD_LOGIC;
      flashValidCheckDone  : IN  STD_LOGIC;
      flashValidFlagOk     : IN  STD_LOGIC;
      -- ConfigUnit signals
		cfgDone              : IN  STD_LOGIC
      );
  END COMPONENT;

  COMPONENT cyclical
    PORT (
      reset_n        : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      -- DPM signals
		comm_dpm_web   : OUT STD_LOGIC;
      comm_dpm_dinb  : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      comm_dpm_doutb : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
      comm_dpm_addrb : OUT STD_LOGIC_VECTOR (5 DOWNTO 0);
      ctrl_dpm       : OUT STD_LOGIC;
      dpm_addra      : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      dpm_dina       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      dpm_douta      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      dpm_wea        : OUT STD_LOGIC;
      -- SC internal signals
		start          : IN  STD_LOGIC;
      done           : OUT STD_LOGIC;
      validFrame     : IN  STD_LOGIC;
      -- PU internal ports
		data_updated   : OUT STD_LOGIC;
      pu_fdb_updated : IN  STD_LOGIC;
      commFailure    : IN  STD_LOGIC
      );
  END COMPONENT;

  COMPONENT sdo_adapter
    PORT(
      reset_n              : IN  STD_LOGIC;
      clk                  : IN  STD_LOGIC;
      -- DPM signals
      comm_dpm_web         : OUT STD_LOGIC;
      comm_dpm_dinb        : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      comm_dpm_doutb       : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
      comm_dpm_addrb       : OUT STD_LOGIC_VECTOR (5 DOWNTO 0);
      ctrl_dpm             : OUT STD_LOGIC;
      -- SC internal signals
      sdoWriteEvent        : IN  STD_LOGIC;
      sdoReadEvent         : IN  STD_LOGIC;
      done                 : OUT STD_LOGIC;
      -- SDO bus signals
      mbxIrq		         : OUT STD_LOGIC;
      memSel		         : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
      rdDataReq		      : IN  STD_LOGIC;
      rdAddr		         : IN  STD_LOGIC_VECTOR (11 DOWNTO 0);
      rdData		         : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      rdDataValid	         : OUT STD_LOGIC;
      wrDataReq		      : IN  STD_LOGIC;
      wrAddr		         : IN  STD_LOGIC_VECTOR (11 DOWNTO 0);
      wrData		         : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
      wrDataBusy	         : OUT STD_LOGIC;
      opCompleted	         : IN  STD_LOGIC;
      opError		         : IN  STD_LOGIC;
      opErrorCode  	      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
  END COMPONENT;
	
  COMPONENT fwInfo
    PORT (
      reset_n        : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      -- SDO bus signals
      mbxIrq         : IN  STD_LOGIC;
      sdoType        : IN  STD_LOGIC_VECTOR (3 DOWNTO 0);
      rdDataReq      : OUT STD_LOGIC;
      rdAddr         : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
      rdData         : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
      rdDataValid    : IN  STD_LOGIC;
      wrDataReq      : OUT STD_LOGIC;
      wrAddr         : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
      wrData         : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      wrDataBusy     : IN  STD_LOGIC;
      sdoOpCompleted : OUT STD_LOGIC;
      sdoOpError     : OUT STD_LOGIC;
      sdoOpErrorCode : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
  END COMPONENT;
	
  COMPONENT cfgUnit
    PORT(
      rst_n               : IN  STD_LOGIC;
      clk                 : IN  STD_LOGIC;
      -- SDO bus signals 
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
      sdoOpCompleted      : OUT STD_LOGIC;
      sdoOpError          : OUT STD_LOGIC;
      -- PU internal ports
      deadTimeInverter1   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter2   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter3   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter4   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter5   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter6   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      cfgDone             : OUT STD_LOGIC;
      bleederTurnOnLevel  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTurnOffLevel : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTestLevel    : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);      
      dcSettleLevel       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcEngageLevel       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcDisengageLevel    : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      mainsVACType        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      noOfPhases          : OUT STD_LOGIC;
      maxNoOfLostFrames   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      mduProtocolVersion  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      wdtTimeout          : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      -- Supervision internal signals
      wdtTimeoutInterval  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
      );
  END COMPONENT;

  COMPONENT memCtrl
    PORT(
      rst_n                : IN  STD_LOGIC;
      clk                  : IN  STD_LOGIC;
      -- SDO bus signals
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
      -- ESM internal signals
      flashToSel           : IN  STD_LOGIC;
      startFlashSelect     : IN  STD_LOGIC;
      flashSelectDone      : OUT STD_LOGIC;
      startFlashValidCheck : IN  STD_LOGIC;
      flashValidCheckDone  : OUT STD_LOGIC;
      flashValidFlagOk     : OUT STD_LOGIC;
      -- Memory ports
      flashSelect          : OUT STD_LOGIC;
      flashSelectMirror    : IN  STD_LOGIC;
      flashMiso            : IN  STD_LOGIC;
      flashMosi            : OUT STD_LOGIC;
      flashSpiCs_n         : OUT STD_LOGIC;
      flashSpiClk          : OUT STD_LOGIC;
      eepromMiso           : IN  STD_LOGIC;
      eepromMosi           : OUT STD_LOGIC;
      eepromSpiCs_n        : OUT STD_LOGIC;
      eepromSpiClk         : OUT STD_LOGIC
      );
  END COMPONENT;

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  -- DPM signals
  SIGNAL dpm_addra             : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL dpm_dina              : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL dpm_douta             : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL dpm_wea               : STD_LOGIC;
  -- supervision signals:
  SIGNAL sup_comm_error        : STD_LOGIC;
  SIGNAL sup_comm_failure_i    : STD_LOGIC;
  SIGNAL resetCommFailure      : STD_LOGIC;
  SIGNAL lostFrames            : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL periodicStarted_i     : STD_LOGIC;
  -- Slave controller signals
  SIGNAL sc_comm_dpm_doutb     : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL sc_comm_dpm_dinb      : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL sc_comm_dpm_addrb     : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL sc_comm_dpm_web       : STD_LOGIC;
  SIGNAL sc_ctrl_dpm		       : STD_LOGIC;
  -- ESM signals
  SIGNAL alControl             : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL alStatus              : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL startUpDone_i         : STD_LOGIC;  
  SIGNAL flashToSel            : STD_LOGIC;
  SIGNAL startFlashSelect      : STD_LOGIC;
  SIGNAL flashSelectDone       : STD_LOGIC;
  SIGNAL startFlashValidCheck  : STD_LOGIC;
  SIGNAL flashValidCheckDone   : STD_LOGIC;
  SIGNAL flashValidFlagOk      : STD_LOGIC;
  SIGNAL ESM_start             : STD_LOGIC;
  SIGNAL ESM_done              : STD_LOGIC;
  SIGNAL ESM_comm_dpm_doutb    : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL ESM_comm_dpm_dinb     : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL ESM_comm_dpm_addrb    : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL ESM_comm_dpm_web      : STD_LOGIC;
  SIGNAL ESM_ctrl_dpm          : STD_LOGIC;
  -- Cyclical signals
  SIGNAL cyclical_start        : STD_LOGIC;
  SIGNAL cyclical_done         : STD_LOGIC;
  SIGNAL validFrame            : STD_LOGIC;
  SIGNAL cycl_comm_dpm_doutb   : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cycl_comm_dpm_dinb    : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cycl_comm_dpm_addrb   : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL cycl_comm_dpm_web     : STD_LOGIC;
  SIGNAL cycl_ctrl_dpm			 : STD_LOGIC;
  -- SDO adapter signals
  SIGNAL mbx_comm_dpm_addrb    : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL mbx_comm_dpm_doutb    : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL mbx_comm_dpm_dinb     : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL mbx_comm_dpm_web      : STD_LOGIC;
  SIGNAL mbx_ctrl_dpm          : STD_LOGIC;
  SIGNAL sdoWriteEvent	       : STD_LOGIC;
  SIGNAL sdoReadEvent          : STD_LOGIC;
  SIGNAL SDO_done              : STD_LOGIC;
  -- SDO bus signals
  SIGNAL mbxIrq                : STD_LOGIC;
  SIGNAL sdoType               : STD_LOGIC_VECTOR (3 DOWNTO 0);
  SIGNAL rdDataReq             : STD_LOGIC;
  SIGNAL rdAddr                : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL rdData                : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL rdDataValid           : STD_LOGIC;
  SIGNAL wrDataReq             : STD_LOGIC;
  SIGNAL wrAddr                : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL wrData                : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL wrDataBusy			    : STD_LOGIC;
  SIGNAL wrDataBusy_d          : STD_LOGIC;  
  SIGNAL sdoOpCompleted	       : STD_LOGIC;
  SIGNAL sdoOpError			    : STD_LOGIC;
  SIGNAL sdoOpErrorCode        : STD_LOGIC_VECTOR(3 DOWNTO 0);
  -- SDO bus muxing locations signals
  CONSTANT RESERVED_INDEX      : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"0";
  CONSTANT CB_FW_INFO          : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"1";
  CONSTANT PB_CALIB_DATA       : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"2";
  CONSTANT PB_HW_INFO          : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"3";
  CONSTANT FW_UPGRADE          : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"4";
  CONSTANT APPLIC_CFG_DATA     : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"5";
  SIGNAL cfgUnitSelected       : STD_LOGIC;
  SIGNAL memCtrlUnitSelected   : STD_LOGIC;
  SIGNAL fwInfoUnitSelected    : STD_LOGIC;
  -- SDO bus FW info signals
  SIGNAL fwInfoRdDataReq       : STD_LOGIC;
  SIGNAL fwInfoRdAddr          : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL fwInfoWrDataReq       : STD_LOGIC;
  SIGNAL fwInfoWrAddr          : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL fwInfoWrData          : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL fwInfoSdoOpCompleted  : STD_LOGIC;
  SIGNAL fwInfoSdoOpError      : STD_LOGIC;
  SIGNAL fwInfoSdoOpErrorCode  : STD_LOGIC_VECTOR(3 DOWNTO 0);
  -- SDO bus Config Unit signals
  SIGNAL cfgRdDataReq          : STD_LOGIC;
  SIGNAL cfgRdAddr             : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL cfgWrDataReq          : STD_LOGIC;
  SIGNAL cfgWrAddr             : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL cfgWrData             : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL cfgSdoOpCompleted     : STD_LOGIC;
  SIGNAL cfgSdoOpError         : STD_LOGIC;
  SIGNAL cfgDone_i             : STD_LOGIC;  
  SIGNAL maxNoOfLostFrames_i   : STD_LOGIC_VECTOR(3 DOWNTO 0);    
  SIGNAL wdtTimeout_i          : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL wdtTimeoutInterval    : STD_LOGIC_VECTOR(15 DOWNTO 0);
  -- SDO bus memory control signals
  SIGNAL memCtrlRdDataReq      : STD_LOGIC;
  SIGNAL memCtrlRdAddr         : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL memCtrlWrDataReq      : STD_LOGIC;
  SIGNAL memCtrlWrAddr         : STD_LOGIC_VECTOR (11 DOWNTO 0);
  SIGNAL memCtrlWrData         : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL memCtrlSdoOpCompleted : STD_LOGIC;
  SIGNAL memCtrlSdoOpError     : STD_LOGIC;
  SIGNAL memCtrlSdoOpErrorCode : STD_LOGIC_VECTOR(3 DOWNTO 0);
  -- PU internal signals
  SIGNAL onlyIgnoreNodes_i     : STD_LOGIC;

BEGIN

  -- Ports internal signals
  onlyIgnoreNodes   <= onlyIgnoreNodes_i;
  startUpDone       <= startUpDone_i;
  sup_comm_failure  <= sup_comm_failure_i;
  periodicStarted   <= periodicStarted_i;
  cfgDone           <= cfgDone_i;
  maxNoOfLostFrames <= maxNoOfLostFrames_i;
  wdtTimeout        <= wdtTimeout_i;

-------------------------------------------------------------------------------
-- Communication DPM bus muxing controller:
-------------------------------------------------------------------------------
  dpm_bus_mux_ctrl : PROCESS (reset_n, clk) IS
  BEGIN
    --the input signals of the commmunication dpm are muxed from the user modules
    IF reset_n = '0' THEN
      comm_dpm_web     <= '0';
      comm_dpm_dinb    <= (OTHERS => '0');
      comm_dpm_addrb   <= (OTHERS => '0');
    ELSIF clk'event AND clk = '1' THEN
      IF sc_ctrl_dpm = '1' THEN
        comm_dpm_dinb  <= sc_comm_dpm_dinb;
        comm_dpm_addrb <= sc_comm_dpm_addrb;
        comm_dpm_web   <= sc_comm_dpm_web;
      ELSIF cycl_ctrl_dpm = '1' THEN
        comm_dpm_dinb  <= cycl_comm_dpm_dinb;
        comm_dpm_addrb <= cycl_comm_dpm_addrb;
        comm_dpm_web   <= cycl_comm_dpm_web;
      ELSIF ESM_ctrl_dpm = '1' THEN
        comm_dpm_dinb  <= ESM_comm_dpm_dinb;
        comm_dpm_addrb <= ESM_comm_dpm_addrb;
        comm_dpm_web   <= ESM_comm_dpm_web;
      ELSIF mbx_ctrl_dpm = '1' THEN
        comm_dpm_dinb  <= mbx_comm_dpm_dinb;
        comm_dpm_addrb <= mbx_comm_dpm_addrb;
        comm_dpm_web   <= mbx_comm_dpm_web;
      END IF;
    END IF;
  END PROCESS dpm_bus_mux_ctrl;

-------------------------------------------------------------------------------
-- Communication DPM bus demuxing controller:
-------------------------------------------------------------------------------
  dpm_bus_demux_ctrl : PROCESS (reset_n, clk) IS
  BEGIN
    --the output signal of the commmunication dpm is demuxed to the user modules        
    IF reset_n = '0' THEN
      sc_comm_dpm_doutb     <= (OTHERS => '0');
      cycl_comm_dpm_doutb   <= (OTHERS => '0');
      ESM_comm_dpm_doutb    <= (OTHERS => '0');
    ELSIF clk'event AND clk = '1' THEN
      IF sc_ctrl_dpm = '1' THEN
        sc_comm_dpm_doutb   <= comm_dpm_doutb;
      ELSIF cycl_ctrl_dpm = '1' THEN
        cycl_comm_dpm_doutb <= comm_dpm_doutb;
      ELSIF ESM_ctrl_dpm = '1' THEN
        ESM_comm_dpm_doutb  <= comm_dpm_doutb;
      ELSIF mbx_ctrl_dpm = '1' THEN
        mbx_comm_dpm_doutb  <= comm_dpm_doutb;
      END IF;
    END IF;
  END PROCESS dpm_bus_demux_ctrl;

-------------------------------------------------------------------------------
-- Mapping of SDO adapter read and write signals:
-------------------------------------------------------------------------------
  mapping : PROCESS (clk, reset_n)
  BEGIN
    IF reset_n = '0' THEN
      cfgUnitSelected <= '0';
      memCtrlUnitSelected <= '0';
      fwInfoUnitSelected <= '0';
    ELSIF clk'event AND clk = '1' THEN
      IF mbxIrq = '1' THEN
        cfgUnitSelected <= '0';
        memCtrlUnitSelected <= '0';
        fwInfoUnitSelected <= '0';
        IF sdoType = APPLIC_CFG_DATA THEN
          cfgUnitSelected <= '1';
        ELSIF sdoType = CB_FW_INFO THEN
          fwInfoUnitSelected <= '1';
        ELSIF sdoType = PB_CALIB_DATA OR
          sdoType = PB_HW_INFO OR sdoType = FW_UPGRADE THEN
          memCtrlUnitSelected <= '1';
        END IF;
      ELSE
        cfgUnitSelected <= cfgUnitSelected;
        memCtrlUnitSelected <= memCtrlUnitSelected;
        fwInfoUnitSelected <= fwInfoUnitSelected;
      END IF;
    END IF;
  END PROCESS mapping;

-------------------------------------------------------------------------------
-- Pipelining of SDO adapter read and write signals:
-------------------------------------------------------------------------------
  pipelining: PROCESS (clk, reset_n)
  BEGIN  
    IF reset_n = '0' THEN
      rdDataReq <= '0';
      rdAddr <= (OTHERS => '0');
      wrDataReq <= '0';      
      wrAddr <= (OTHERS => '0');
      wrData <= (OTHERS => '0');
      wrDataBusy_d <= '0';
    ELSIF clk'event AND clk = '1' THEN
      wrDataBusy_d <= wrDataBusy;
      IF memCtrlUnitSelected = '1' THEN
        rdDataReq <= memCtrlRdDataReq;
        rdAddr <= memCtrlRdAddr;
        wrDataReq <= memCtrlWrDataReq;
        wrAddr <= memCtrlWrAddr;
        wrData <= memCtrlWrData;
      ELSIF fwInfoUnitSelected = '1' THEN
        rdDataReq <= fwInfoRdDataReq;
        rdAddr <= fwInfoRdAddr;
        wrDataReq <= fwInfoWrDataReq;
        wrAddr <= fwInfoWrAddr;
        wrData <= fwInfoWrData;
      ELSIF cfgUnitSelected = '1' THEN
        rdDataReq <= cfgRdDataReq;
        rdAddr <= cfgRdAddr;
        wrDataReq <= cfgWrDataReq;
        wrAddr <= cfgWrAddr;
        wrData <= cfgWrData;
      ELSE
        rdDataReq <= '0';
        rdAddr <= (OTHERS => '0');
        wrDataReq <= '0';
        wrAddr <= (OTHERS => '0');
        wrData <= (OTHERS => '0');
      END IF;
    END IF;
  END PROCESS pipelining;
  
  -- SDO bus selection
  sdoOpCompleted <= memCtrlSdoOpCompleted WHEN memCtrlUnitSelected = '1' ELSE
                    fwInfoSdoOpCompleted  WHEN fwInfoUnitSelected  = '1' ELSE
                    cfgSdoOpCompleted     WHEN cfgUnitSelected     = '1' ELSE
                    '0';
  sdoOpError <= memCtrlSdoOpError     WHEN memCtrlUnitSelected = '1' ELSE
                    fwInfoSdoOpError  WHEN fwInfoUnitSelected  = '1' ELSE
                    cfgSdoOpError     WHEN cfgUnitSelected     = '1' ELSE
                    '0';
  sdoOpErrorCode <= memCtrlSdoOpErrorCode WHEN memCtrlUnitSelected = '1' ELSE
                    fwInfoSdoOpErrorCode  WHEN fwInfoUnitSelected  = '1' ELSE
                    "0000";

-------------------------------------------------------------------------------
-- Component instatiations: 
-------------------------------------------------------------------------------	

  sc_dpm_inst : sc_dpm
    PORT MAP (
      addra    => dpm_addra,
      addrb    => pu_dpm_addrb,
      clka     => clk,
      clkb     => pu_dpm_clkb,
      dina     => dpm_dina,
      dinb     => pu_dpm_dinb,
      douta    => dpm_douta,
      doutb    => pu_dpm_doutb,
      wea(0)   => dpm_wea,
      web(0)   => pu_dpm_web
      );

  supervision_inst : supervision
    PORT MAP(
      reset_n             => reset_n,
      clk                 => clk,
      -- IRQ signals
      irq_synch_pulse     => irq_synch_pulse,
      -- SC internal signals
      comm_error          => sup_comm_error,
      comm_failure        => sup_comm_failure_i, 
      lostFrames          => lostFrames,
      resetCommFailure    => resetCommFailure,
      periodicStarted     => periodicStarted_i,
      -- ConfigUnit signals
      wdtTimeout          => wdtTimeout_i,
      wdtTimeoutInterval  => wdtTimeoutInterval,
      maxNoOfLostFrames   => maxNoOfLostFrames_i
      );

  slaveController_inst : slaveController
    PORT MAP (
      reset_n              => reset_n,
      clk                  => clk,
      -- IRQ signals
      eventTrigg           => irq_synch_pulse,
      irqLevel             => irq_level,
      -- DPM signals
      comm_dpm_addrb       => sc_comm_dpm_addrb,
      comm_dpm_doutb       => sc_comm_dpm_doutb,
      comm_dpm_dinb        => sc_comm_dpm_dinb,
      comm_dpm_web         => sc_comm_dpm_web,
      ctrl_dpm             => sc_ctrl_dpm,
		-- ESM internal signals
      ESM_start            => ESM_start,
      ESM_done             => ESM_done,
      alStatus             => alStatus,
      alControl		      => alControl,
      startUpDone          => startUpDone_i,
		-- SDO internal signals
      sdoWriteEvent        => sdoWriteEvent,
      sdoReadEvent         => sdoReadEvent,
      SDO_done             => SDO_done,
		-- Cyclical internal signals
      cyclical_start       => cyclical_start,
      cyclical_done        => cyclical_done,
      validFrame           => validFrame,
		-- Supervision internal signals
      errorTrigg           => sup_comm_error,
      commFailure          => sup_comm_failure_i,
      lostFrames           => lostFrames,
      resetCommFailure     => resetCommFailure,
      periodicStarted      => periodicStarted_i,
      -- PU internal ports
      activeNodes          => activeNodes,
      onlyIgnoreNodes      => onlyIgnoreNodes_i,
      puTrigg              => puTrigg, 
      puErrorTrigg         => puErrorTrigg,
      sampleADCEveryPeriod => sampleADCEveryPeriod,
      powerBoardSupplyFail => powerBoardSupplyFail
      );
      
  ESM_inst : ESM
    PORT MAP (
      reset_n              => reset_n,
      clk                  => clk,
      -- DPM signals
      comm_dpm_addrb       => ESM_comm_dpm_addrb,
      comm_dpm_doutb       => ESM_comm_dpm_doutb,
      comm_dpm_dinb        => ESM_comm_dpm_dinb,
      comm_dpm_web         => ESM_comm_dpm_web,
      ctrl_dpm             => ESM_ctrl_dpm,
      -- SC internal signals
      start                => ESM_start,
      done                 => ESM_done,
      alStatus             => alStatus,
      alControl            => alControl,
      startUpDone          => startUpDone_i,
      -- Memory signals
      reconfig_n           => reconfig_n,
      flashSelectMirror    => flashSelectMirror,
      flashToSel           => flashToSel,
      startFlashSelect     => startFlashSelect,
      flashSelectDone      => flashSelectDone,
      startFlashValidCheck => startFlashValidCheck,
      flashValidCheckDone  => flashValidCheckDone,
      flashValidFlagOk     => flashValidFlagOk,
      -- ConfigUnit signals
      cfgDone              => cfgDone_i
      );

  cyclical_inst : cyclical
    PORT MAP (
      reset_n        => reset_n,
      clk            => clk,
      -- DPM signals
      comm_dpm_addrb => cycl_comm_dpm_addrb,
      comm_dpm_doutb => cycl_comm_dpm_doutb,
      comm_dpm_dinb  => cycl_comm_dpm_dinb,
      comm_dpm_web   => cycl_comm_dpm_web,
      ctrl_dpm       => cycl_ctrl_dpm,
      dpm_addra      => dpm_addra,
      dpm_dina       => dpm_dina,
      dpm_douta      => dpm_douta,
      dpm_wea        => dpm_wea,
      -- SC internal signals
      start          => cyclical_start,
      done           => cyclical_done,
      validFrame     => validFrame,
      -- PU internal ports
      data_updated   => cyclical_pu_data_updated,
      pu_fdb_updated => pu_fdb_updated,
      commFailure    => sup_comm_failure_i
      );

  sdo_adapter_inst : sdo_adapter
    PORT MAP (
      reset_n           => reset_n,
      clk               => clk,
      -- DPM signals
		comm_dpm_addrb    => mbx_comm_dpm_addrb,
      comm_dpm_doutb    => mbx_comm_dpm_doutb,
      comm_dpm_dinb     => mbx_comm_dpm_dinb,
      comm_dpm_web      => mbx_comm_dpm_web,
      ctrl_dpm          => mbx_ctrl_dpm,
      -- SC internal signals
		sdoWriteEvent     => sdoWriteEvent,
      sdoReadEvent      => sdoReadEvent,
      done              => SDO_done,
      -- SDO bus signals
      mbxIrq            => mbxIrq,
      memSel            => sdoType,
      rdDataReq         => rdDataReq,
      rdAddr            => rdAddr,
      rdData            => rdData,
      rdDataValid       => rdDataValid,
      wrDataReq         => wrDataReq,
      wrAddr            => wrAddr,
      wrData            => wrData,
      wrDataBusy        => wrDataBusy,
      opCompleted       => sdoOpCompleted,
      opError           => sdoOpError,
      opErrorCode       => sdoOpErrorCode
      );

  fw_info_inst : fwInfo
    PORT MAP (
      reset_n        => reset_n,
      clk            => clk,
      -- SDO bus signals
      mbxIrq         => mbxIrq,
      sdoType        => sdoType,
      rdDataReq      => fwInfoRdDataReq,
      rdAddr         => fwInfoRdAddr,
      rdData         => rdData,
      rdDataValid    => rdDataValid,
      wrDataReq      => fwInfoWrDataReq,
      wrAddr         => fwInfoWrAddr,
      wrData         => fwInfoWrData,
      wrDataBusy     => wrDataBusy_d,
      sdoOpCompleted => fwInfoSdoOpCompleted,
      sdoOpError     => fwInfoSdoOpError,
      sdoOpErrorCode => fwInfoSdoOpErrorCode
      );

  cfgUnit_inst : cfgUnit
    PORT MAP (
      rst_n               => reset_n,
      clk                 => clk,
      -- SDO bus signals
      mbxIrq              => mbxIrq,
      sdoType             => sdoType,
      rdDataReq           => cfgRdDataReq,
      rdAddr              => cfgRdAddr,
      rdData              => rdData,
      rdDataValid         => rdDataValid,
      wrDataReq           => cfgWrDataReq,
      wrAddr              => cfgWrAddr,
      wrData              => cfgWrData,
      wrDataBusy          => wrDataBusy_d,
      sdoOpCompleted      => cfgSdoOpCompleted,
      sdoOpError          => cfgSdoOpError,
      -- PU internal ports
      deadTimeInverter1   => deadTimeInverter1,
      deadTimeInverter2   => deadTimeInverter2,
      deadTimeInverter3   => deadTimeInverter3,
      deadTimeInverter4   => deadTimeInverter4,
      deadTimeInverter5   => deadTimeInverter5,
      deadTimeInverter6   => deadTimeInverter6,
      cfgDone             => cfgDone_i,
      bleederTurnOnLevel  => bleederTurnOnLevel,
      bleederTurnOffLevel => bleederTurnOffLevel,
      bleederTestLevel    => bleederTestLevel,      
      dcSettleLevel       => dcSettleLevel,
      dcEngageLevel       => dcEngageLevel,
      dcDisengageLevel    => dcDisengageLevel,
      mainsVACType        => mainsVACType,
      noOfPhases          => noOfPhases,
      maxNoOfLostFrames   => maxNoOfLostFrames_i,
      mduProtocolVersion  => mduProtocolVersion,
      wdtTimeout          => wdtTimeout_i,
      -- Supervision internal signals
      wdtTimeoutInterval  => wdtTimeoutInterval
      );

  memCtrl_inst : memCtrl
    PORT MAP (
      rst_n                => reset_n,
      clk                  => clk,
      -- SDO bus signals
      mbxIrq               => mbxIrq,
      sdoType              => sdoType,
      rdDataReq            => memCtrlRdDataReq,
      rdAddr               => memCtrlRdAddr,
      rdData               => rdData,
      rdDataValid          => rdDataValid,
      wrDataReq            => memCtrlWrDataReq,
      wrAddr               => memCtrlWrAddr,
      wrData               => memCtrlWrData,
      wrDataBusy           => wrDataBusy_d,
      sdoOpCompleted       => memCtrlSdoOpCompleted,
      sdoOpError           => memCtrlSdoOpError,
      sdoOpErrorCode       => memCtrlSdoOpErrorCode,
      -- ESM internal signals
      flashToSel           => flashToSel,
      startFlashSelect     => startFlashSelect,
      flashSelectDone      => flashSelectDone,
      startFlashValidCheck => startFlashValidCheck,
      flashValidCheckDone  => flashValidCheckDone,
      flashValidFlagOk     => flashValidFlagOk,
      -- Memory ports
      flashSelect          => flashSelect,
      flashSelectMirror    => flashSelectMirror,
      flashMiso            => flashMiso,
      flashMosi            => flashMosi,
      flashSpiCs_n         => flashSpiCs_n,
      flashSpiClk          => flashSpiClk,
      eepromMiso           => eepromMiso,
      eepromMosi           => eepromMosi,
      eepromSpiCs_n        => eepromSpiCs_n,
      eepromSpiClk         => eepromSpiClk
      );

END rtl;

