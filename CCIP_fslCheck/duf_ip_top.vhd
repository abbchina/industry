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
-- Title:               Drive Unit Firmware IP top entity
-- File name:           duf_top/duf_ip_top.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.03
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-10-20
-- **************************************************************************************
-- Related files:       duf_tb/duf_ip_top_tb.vhd
--                      duf_top/Communication_top.vhd
--                      duf_sc/SlaveController_top.vhd
--                      duf_pu/PowerUnit_top.vhd
-- **************************************************************************************
-- Functional description:
--
-- This is the top entity for the Current Control IP implementation and thus it
-- instantiating several components. Among others, the Communication application related
-- components, the Slave Controller and the Power Unit.
--
-- **************************************************************************************
-- Revision 0.00 - 090925, SEROP/Magnus Tysell
-- Copied from ecs_top.vhd (Revision 0.16).
-- **************************************************************************************
-- Revision 0.01 - 090925, CNABB/Ye-Ye Zhang
-- Removed EtherCAT and its related application.
-- * Removed EtherCAT IP core.
-- * Replaced MII bus with FSL bus.
-- * Removed DCM IP core and use FSL clk/rst instead.
-- * Disabled ADC VIN ports for ADC version changed.
-- * Removed median filters and corresponding PHY ports and signals.
-- * Updated FSL interface in Communication_top entity interface.
-- * Added SYS_IRQ input pin and updated irq related signals.
-- * Removed pdi_synch process and PDI marks. 
-- * Removed non-used signal DEV_STATE.
-- **************************************************************************************
-- Revision 0.02 - 090927, CNABB/Ye-Ye Zhang
-- Updated test pins and ucf constraints info.
-- * Removed MII Port 0 and 1.
-- * Removed other EtherCAT ports.
-- * Removed PHY and PROM ports.
-- * Removed LED ports.
-- * Removed CB EEPROM ports.
-- * Replaced ref_clk and dcm_locked ports.
-- * Replaced "FLASH_MISO" from "R12" to "T8" for updated DSQC415 HW p2.
-- * Replaced "FLASH_SCLK" from "R10" to "R9" for updated DSQC415 HW p2.
-- * Updated test pins for using "R12" and "R10" pins.
-- * Updated test pins to TP 111~117.
-- * Removed ucf file but kept the ucf constraints info in this project.
-- **************************************************************************************
-- Revision 0.03 - 091020, CNABB/Ye-Ye Zhang
-- Renamed from puc to duf.
-- * Replaced Power Unit Controller with Drive Unit Firmware.
-- ************************************************************************************** 

-- **************************************************************************************
--
-- Definition of Ports
-- FSL_Clk         : Synchronous clock
-- FSL_Rst         : System reset, should always come from FSL bus
-- FSL_S_Clk       : Slave asynchronous clock
-- FSL_S_Read      : Read signal, requiring next available input to be read
-- FSL_S_Data      : Input data
-- FSL_S_CONTROL   : Control Bit, indicating the input data are control word
-- FSL_S_Exists    : Data Exist Bit, indicating data exist in the input FSL bus
-- FSL_M_Clk       : Master asynchronous clock
-- FSL_M_Write     : Write signal, enabling writing to output FSL bus
-- FSL_M_Data      : Output data
-- FSL_M_Control   : Control Bit, indicating the output data are contol word
-- FSL_M_Full      : Full Bit, indicating output FSL bus is full
--
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY duf_ip_top IS
  PORT(
    -- FSL ports
	 -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol ports, do not add or delete. 
    FSL_Clk        : in  std_logic;
    FSL_Rst        : in	 std_logic;
    FSL_S_Clk      : out std_logic;
    FSL_S_Read     : out std_logic;
    FSL_S_Data     : in  std_logic_vector(0 to 31);
    FSL_S_Control  : in  std_logic;
    FSL_S_Exists   : in  std_logic;
    FSL_M_Clk      : out std_logic;
    FSL_M_Write    : out std_logic;
    FSL_M_Data     : out std_logic_vector(0 to 31);
    FSL_M_Control  : out std_logic;
    FSL_M_Full     : in  std_logic;
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
    -- IRQ ports
	 SYS_IRQ        : IN  STD_LOGIC;
	 -- PU PWM ports
    U_pwm_top_1    : OUT STD_LOGIC;
    U_pwm_bottom_1 : OUT STD_LOGIC;
    V_pwm_top_1    : OUT STD_LOGIC;
    V_pwm_bottom_1 : OUT STD_LOGIC;
    W_pwm_top_1    : OUT STD_LOGIC;
    W_pwm_bottom_1 : OUT STD_LOGIC;
    U_pwm_top_2    : OUT STD_LOGIC;
    U_pwm_bottom_2 : OUT STD_LOGIC;
    V_pwm_top_2    : OUT STD_LOGIC;
    V_pwm_bottom_2 : OUT STD_LOGIC;
    W_pwm_top_2    : OUT STD_LOGIC;
    W_pwm_bottom_2 : OUT STD_LOGIC;
    U_pwm_top_3    : OUT STD_LOGIC;
    U_pwm_bottom_3 : OUT STD_LOGIC;
    V_pwm_top_3    : OUT STD_LOGIC;
    V_pwm_bottom_3 : OUT STD_LOGIC;
    W_pwm_top_3    : OUT STD_LOGIC;
    W_pwm_bottom_3 : OUT STD_LOGIC;
    U_pwm_top_4    : OUT STD_LOGIC;
    U_pwm_bottom_4 : OUT STD_LOGIC;
    V_pwm_top_4    : OUT STD_LOGIC;
    V_pwm_bottom_4 : OUT STD_LOGIC;
    W_pwm_top_4    : OUT STD_LOGIC;
    W_pwm_bottom_4 : OUT STD_LOGIC;
    U_pwm_top_5    : OUT STD_LOGIC;
    U_pwm_bottom_5 : OUT STD_LOGIC;
    V_pwm_top_5    : OUT STD_LOGIC;
    V_pwm_bottom_5 : OUT STD_LOGIC;
    W_pwm_top_5    : OUT STD_LOGIC;
    W_pwm_bottom_5 : OUT STD_LOGIC;
    U_pwm_top_6    : OUT STD_LOGIC;
    U_pwm_bottom_6 : OUT STD_LOGIC;
    V_pwm_top_6    : OUT STD_LOGIC;
    V_pwm_bottom_6 : OUT STD_LOGIC;
    W_pwm_top_6    : OUT STD_LOGIC;
    W_pwm_bottom_6 : OUT STD_LOGIC;
    -- PU ADC ports
    ADC_UIN1       : OUT STD_LOGIC;
    ADC_UOUT1      : IN  STD_LOGIC;
    ADC_SCLK1      : OUT STD_LOGIC;
    ADC_CS_N1      : OUT STD_LOGIC;
--  ADC_VIN1       : OUT STD_LOGIC;
    ADC_VOUT1      : IN  STD_LOGIC;
    ADC_UIN2       : OUT STD_LOGIC;
    ADC_UOUT2      : IN  STD_LOGIC;
    ADC_SCLK2      : OUT STD_LOGIC;
    ADC_CS_N2      : OUT STD_LOGIC;
--  ADC_VIN2       : OUT STD_LOGIC;
    ADC_VOUT2      : IN  STD_LOGIC;
    ADC_UIN3       : OUT STD_LOGIC;
    ADC_UOUT3      : IN  STD_LOGIC;
    ADC_SCLK3      : OUT STD_LOGIC;
    ADC_CS_N3      : OUT STD_LOGIC;
--  ADC_VIN3       : OUT STD_LOGIC;
    ADC_VOUT3      : IN  STD_LOGIC;
    ADC_UIN4       : OUT STD_LOGIC;
    ADC_UOUT4      : IN  STD_LOGIC;
    ADC_SCLK4      : OUT STD_LOGIC;
    ADC_CS_N4      : OUT STD_LOGIC;
--  ADC_VIN4       : OUT STD_LOGIC;
    ADC_VOUT4      : IN  STD_LOGIC;
    ADC_UIN5       : OUT STD_LOGIC;
    ADC_UOUT5      : IN  STD_LOGIC;
    ADC_SCLK5      : OUT STD_LOGIC;
    ADC_CS_N5      : OUT STD_LOGIC;
--  ADC_VIN5       : OUT STD_LOGIC;
    ADC_VOUT5      : IN  STD_LOGIC;
    ADC_UIN6       : OUT STD_LOGIC;
    ADC_UOUT6      : IN  STD_LOGIC;
    ADC_SCLK6      : OUT STD_LOGIC;
    ADC_CS_N6      : OUT STD_LOGIC;
--  ADC_VIN6       : OUT STD_LOGIC;
    ADC_VOUT6      : IN  STD_LOGIC;
    -- PU related ports
    DR_TRIP1_N     : IN  STD_LOGIC;
    DR_TRIP2_N     : IN  STD_LOGIC;
    DR_TRIP3_N     : IN  STD_LOGIC;
    DR_TRIP4_N     : IN  STD_LOGIC;
    DR_TRIP5_N     : IN  STD_LOGIC;
    DR_TRIP6_N     : IN  STD_LOGIC;
    FAULT_CLR1     : OUT STD_LOGIC;
    FAULT_CLR2     : OUT STD_LOGIC;
    FAULT_CLR3     : OUT STD_LOGIC;
    FAULT_CLR4     : OUT STD_LOGIC;
    FAULT_CLR5     : OUT STD_LOGIC;
    FAULT_CLR6     : OUT STD_LOGIC;
    BLEEDER_ON     : OUT STD_LOGIC;
    RELAY_ON       : OUT STD_LOGIC;
    GATEVOLT_17VOK : IN  STD_LOGIC;
    PWROK          : IN  STD_LOGIC;
    phaseTrig      : IN  STD_LOGIC;
    bleederFltSD_n : IN  STD_LOGIC;
    bleederFltClr  : OUT STD_LOGIC;
    WDKick         : OUT STD_LOGIC;
    AX_DETACH_N    : OUT STD_LOGIC;
    -- SC related ports
    FLASHSELECT    : OUT STD_LOGIC;
    SELECTEDFLASH  : IN  STD_LOGIC;
    PROM_MISO      : IN  STD_LOGIC;
    PROM_MOSI      : OUT STD_LOGIC;
    PROM_CS_N      : OUT STD_LOGIC;
    PROM_SCK       : OUT STD_LOGIC;
    FLASH_MISO     : IN  STD_LOGIC;
    FLASH_MOSI     : OUT STD_LOGIC;
    FLASH_CS_N     : OUT STD_LOGIC;
    FLASH_SCLK     : OUT STD_LOGIC;
    RECONFIG_N     : OUT STD_LOGIC;
    -- Test ports
    TP_111         : OUT STD_LOGIC;
    TP_112         : IN  STD_LOGIC;
    TP_113         : OUT STD_LOGIC;
    TP_114         : OUT STD_LOGIC;
    TP_115         : OUT STD_LOGIC;
    TP_116         : IN  STD_LOGIC;
    TP_117         : OUT STD_LOGIC;
	 -- Legacy ports
    WDOK           : IN  STD_LOGIC
    );
END duf_ip_top;

ARCHITECTURE rtl OF duf_ip_top IS

  COMPONENT Communication_top
    PORT(
      reset_n        : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      -- FSL ports
      -- DO NOT EDIT BELOW THIS LINE ---------------------
      -- Bus protocol ports, do not add or delete. 
      FSL_S_Clk      : out std_logic;
      FSL_S_Read     : out std_logic;
      FSL_S_Data     : in  std_logic_vector(0 to 31);
      FSL_S_Control  : in  std_logic;
      FSL_S_Exists   : in  std_logic;
      FSL_M_Clk      : out std_logic;
      FSL_M_Write    : out std_logic;
      FSL_M_Data     : out std_logic_vector(0 to 31);
      FSL_M_Control  : out std_logic;
      FSL_M_Full     : in  std_logic;
      -- DO NOT EDIT ABOVE THIS LINE ---------------------
      -- DPM signals
		comm_dpm_web   : IN  STD_LOGIC;
      comm_dpm_dinb  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_addrb : IN  STD_LOGIC_VECTOR(5 DOWNTO 0)
      );
  END COMPONENT Communication_top;

  COMPONENT SlaveController_top
    PORT(
      reset_n                  : IN  STD_LOGIC;
      clk                      : IN  STD_LOGIC;
      -- IRQ signals
		irq_level                : IN  STD_LOGIC;
      irq_synch_pulse          : IN  STD_LOGIC;
      -- DPM signals
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
		-- PU internal signals
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
      onlyIgnoreNodes          : OUT std_logic;
		cyclical_pu_data_updated : OUT STD_LOGIC;
      pu_fdb_updated           : IN  STD_LOGIC;
      sup_comm_failure         : OUT STD_LOGIC;
	   -- Legacy signals
      maxNoOfLostFrames        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      mduProtocolVersion       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      startUpDone              : OUT STD_LOGIC
      );
  END COMPONENT SlaveController_top;

  COMPONENT PowerUnit_top
    GENERIC(
      C_CLK_FREQ               : integer range 10_000_000 to 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : integer range 63 to 126 := 126; -- PWM update rate in microseconds 
      C_PWM_MIN_PULSE_WIDTH_US : integer range 3 to 6:= 5   -- PWM min pulse width time in microseconds
      );
    PORT(
      Rst_n           : IN  STD_LOGIC;
      Clk             : IN  STD_LOGIC;
      -- DPM signals
      Addrb           : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      Dinb            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      Doutb           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      Web             : OUT STD_LOGIC;
      -- PU PWM ports
      U_pwm_top_1     : OUT STD_LOGIC;
      U_pwm_bottom_1  : OUT STD_LOGIC;
      V_pwm_top_1     : OUT STD_LOGIC;
      V_pwm_bottom_1  : OUT STD_LOGIC;
      W_pwm_top_1     : OUT STD_LOGIC;
      W_pwm_bottom_1  : OUT STD_LOGIC;
      U_pwm_top_2     : OUT STD_LOGIC;
      U_pwm_bottom_2  : OUT STD_LOGIC;
      V_pwm_top_2     : OUT STD_LOGIC;
      V_pwm_bottom_2  : OUT STD_LOGIC;
      W_pwm_top_2     : OUT STD_LOGIC;
      W_pwm_bottom_2  : OUT STD_LOGIC;
      U_pwm_top_3     : OUT STD_LOGIC;
      U_pwm_bottom_3  : OUT STD_LOGIC;
      V_pwm_top_3     : OUT STD_LOGIC;
      V_pwm_bottom_3  : OUT STD_LOGIC;
      W_pwm_top_3     : OUT STD_LOGIC;
      W_pwm_bottom_3  : OUT STD_LOGIC;
      U_pwm_top_4     : OUT STD_LOGIC;
      U_pwm_bottom_4  : OUT STD_LOGIC;
      V_pwm_top_4     : OUT STD_LOGIC;
      V_pwm_bottom_4  : OUT STD_LOGIC;
      W_pwm_top_4     : OUT STD_LOGIC;
      W_pwm_bottom_4  : OUT STD_LOGIC;
      U_pwm_top_5     : OUT STD_LOGIC;
      U_pwm_bottom_5  : OUT STD_LOGIC;
      V_pwm_top_5     : OUT STD_LOGIC;
      V_pwm_bottom_5  : OUT STD_LOGIC;
      W_pwm_top_5     : OUT STD_LOGIC;
      W_pwm_bottom_5  : OUT STD_LOGIC;
      U_pwm_top_6     : OUT STD_LOGIC;
      U_pwm_bottom_6  : OUT STD_LOGIC;
      V_pwm_top_6     : OUT STD_LOGIC;
      V_pwm_bottom_6  : OUT STD_LOGIC;
      W_pwm_top_6     : OUT STD_LOGIC;
      W_pwm_bottom_6  : OUT STD_LOGIC;
      -- PU ADC ports
      ADC_UIN1        : OUT STD_LOGIC;
      ADC_UOUT1       : IN  STD_LOGIC;
      ADC_SCLK1       : OUT STD_LOGIC;
      ADC_CS_N1       : OUT STD_LOGIC;
      ADC_VIN1        : OUT STD_LOGIC;
      ADC_VOUT1       : IN  STD_LOGIC;
      ADC_UIN2        : OUT STD_LOGIC;
      ADC_UOUT2       : IN  STD_LOGIC;
      ADC_SCLK2       : OUT STD_LOGIC;
      ADC_CS_N2       : OUT STD_LOGIC;
      ADC_VIN2        : OUT STD_LOGIC;
      ADC_VOUT2       : IN  STD_LOGIC;
      ADC_UIN3        : OUT STD_LOGIC;
      ADC_UOUT3       : IN  STD_LOGIC;
      ADC_SCLK3       : OUT STD_LOGIC;
      ADC_CS_N3       : OUT STD_LOGIC;
      ADC_VIN3        : OUT STD_LOGIC;
      ADC_VOUT3       : IN  STD_LOGIC;
      ADC_UIN4        : OUT STD_LOGIC;
      ADC_UOUT4       : IN  STD_LOGIC;
      ADC_SCLK4       : OUT STD_LOGIC;
      ADC_CS_N4       : OUT STD_LOGIC;
      ADC_VIN4        : OUT STD_LOGIC;
      ADC_VOUT4       : IN  STD_LOGIC;
      ADC_UIN5        : OUT STD_LOGIC;
      ADC_UOUT5       : IN  STD_LOGIC;
      ADC_SCLK5       : OUT STD_LOGIC;
      ADC_CS_N5       : OUT STD_LOGIC; 
      ADC_VIN5        : OUT STD_LOGIC;
      ADC_VOUT5       : IN  STD_LOGIC;
      ADC_UIN6        : OUT STD_LOGIC;
      ADC_UOUT6       : IN  STD_LOGIC;
      ADC_SCLK6       : OUT STD_LOGIC;
      ADC_CS_N6       : OUT STD_LOGIC;
      ADC_VIN6        : OUT STD_LOGIC;
      ADC_VOUT6       : IN  STD_LOGIC;
      -- PU related ports
      gateDriveTrip_n : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
      gateDriveFltClr : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      bleederOn       : OUT STD_LOGIC;
      relayOn         : OUT STD_LOGIC;
      GATEVOLT_17VOK  : IN  STD_LOGIC;
      PWROK           : IN  STD_LOGIC;
      phaseTrig       : IN  STD_LOGIC;
      bleederFltClr   : OUT STD_LOGIC;
      bleederFltSD_n  : IN  STD_LOGIC;
      WDKick          : OUT STD_LOGIC;
      AX_DETACH_N     : OUT STD_LOGIC;
      -- SC internal signals
      deadTimeInverter1    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter2    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter3    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter4    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter5    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter6    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      puTrigg              : IN  STD_LOGIC;
      puErrorTrigg         : IN  STD_LOGIC;
      periodicStarted      : IN  STD_LOGIC;
      activeNodes          : IN  STD_LOGIC_VECTOR(6 DOWNTO 1);
      cfgDone              : IN  STD_LOGIC;
      bleederTurnOnLevel   : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTurnOffLevel  : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTestLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcSettleLevel        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcEngageLevel        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcDisengageLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      mainsVACType         : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      noOfPhases           : IN  STD_LOGIC;
      wdtTimeout           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      powerBoardSupplyFail : OUT STD_LOGIC;
      sampleADCEveryPeriod : IN  STD_LOGIC;
      onlyIgnoreNodes      : IN  STD_LOGIC;
		pu_data_updated      : IN  STD_LOGIC;
      fdb_updated          : OUT STD_LOGIC;
      comm_failure         : IN  STD_LOGIC;
      -- Test ports    
      TP_201          : OUT STD_LOGIC;
      TP_202          : OUT STD_LOGIC;
      TP_203          : OUT STD_LOGIC;
      TP_204          : OUT STD_LOGIC;
      TP_205          : OUT STD_LOGIC;
      TP_209          : OUT STD_LOGIC
      );
  END COMPONENT PowerUnit_top;

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  CONSTANT C_CLK_FREQ                  : INTEGER := 100000000;
  CONSTANT C_PWM_UPDATE_RATE_US        : INTEGER := 126;
  CONSTANT C_PWM_MIN_PULSE_WIDTH_US    : INTEGER := 5;

  SIGNAL reset_n                       : STD_LOGIC;
  SIGNAL clk100                        : STD_LOGIC;
  SIGNAL net_gnd                       : STD_LOGIC;
  SIGNAL net_vcc                       : STD_LOGIC;
  -- IRQ signals
  SIGNAL irq_synch_delay               : STD_LOGIC;
  SIGNAL irq_synch_now                 : STD_LOGIC;
  SIGNAL irq_synch_last                : STD_LOGIC;
  SIGNAL irq_synch_pulse               : STD_LOGIC;
  -- DPM signals
  SIGNAL comm_dpm_web                  : STD_LOGIC;
  SIGNAL comm_dpm_dinb                 : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL comm_dpm_doutb                : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL comm_dpm_addrb                : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL pu_dpm_web                    : STD_LOGIC;
  SIGNAL pu_dpm_dinb                   : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL pu_dpm_doutb                  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL pu_dpm_addrb                  : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL pu_dpm_clkb                   : STD_LOGIC;
  -- SC & PU internal signals
  SIGNAL deadTimeInverter1             : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL deadTimeInverter2             : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL deadTimeInverter3             : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL deadTimeInverter4             : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL deadTimeInverter5             : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL deadTimeInverter6             : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL puTrigg                       : STD_LOGIC;
  SIGNAL puErrorTrigg                  : STD_LOGIC;
  SIGNAL periodicStarted               : STD_LOGIC;
  SIGNAL activeNodes                   : STD_LOGIC_VECTOR(6 DOWNTO 1);
  SIGNAL cfgDone                       : STD_LOGIC;
  SIGNAL bleederTurnOnLevel            : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL bleederTurnOffLevel           : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL bleederTestLevel              : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL dcSettleLevel                 : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL dcEngageLevel                 : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL dcDisengageLevel              : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL mainsVACType                  : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL noOfPhases                    : STD_LOGIC;
  SIGNAL wdtTimeout                    : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL powerBoardSupplyFail_i        : STD_LOGIC;
  SIGNAL sampleADCEveryPeriod          : STD_LOGIC;
  SIGNAL onlyIgnoreNodes               : STD_LOGIC;
  SIGNAL cyclical_pu_data_updated      : STD_LOGIC;
  SIGNAL pu_fdb_updated                : STD_LOGIC;
  SIGNAL sup_comm_failure              : STD_LOGIC;
  -- PU related ports
  SIGNAL gateDriveTrip_n               : STD_LOGIC_VECTOR(6 DOWNTO 1);
  SIGNAL gateDriveFltClr               : STD_LOGIC_VECTOR(6 DOWNTO 1);
  SIGNAL bleederOn_i                   : STD_LOGIC;
  SIGNAL relayOn_i                     : STD_LOGIC;
  SIGNAL AX_DETACH_N_i                 : STD_LOGIC;
  -- Test ports
  SIGNAL TP_111_i                      : STD_LOGIC;
  SIGNAL TP_115_i                      : STD_LOGIC;
  SIGNAL TP_113_i                      : STD_LOGIC;
  SIGNAL TP_114_i                      : STD_LOGIC;
  SIGNAL toggleOnIRQ                   : STD_LOGIC;
  SIGNAL ticksSinceLastIRQ             : STD_LOGIC_VECTOR(15 DOWNTO 0);
  ATTRIBUTE keep                       : STRING;
  ATTRIBUTE keep OF ticksSinceLastIRQ  : SIGNAL IS "TRUE";
  -- Legacy signals
  SIGNAL startUpDone                   : STD_LOGIC;

BEGIN

  clk100      <= FSL_CLK;
  reset_n     <= NOT FSL_RST;
  net_gnd     <= '0';
  net_vcc     <= '1';
  -- PU related ports
  FAULT_CLR1  <= gateDriveFltClr(1);
  FAULT_CLR2  <= gateDriveFltClr(2);
  FAULT_CLR3  <= gateDriveFltClr(3);
  FAULT_CLR4  <= gateDriveFltClr(4);
  FAULT_CLR5  <= gateDriveFltClr(5);
  FAULT_CLR6  <= gateDriveFltClr(6);
  gateDriveTrip_n(1)  <= DR_TRIP1_N; 
  gateDriveTrip_n(2)  <= DR_TRIP2_N;
  gateDriveTrip_n(3)  <= DR_TRIP3_N;
  gateDriveTrip_n(4)  <= DR_TRIP4_N; 
  gateDriveTrip_n(5)  <= DR_TRIP5_N; 
  gateDriveTrip_n(6)  <= DR_TRIP6_N; 
  BLEEDER_ON  <= bleederOn_i;
  RELAY_ON    <= relayOn_i;
  AX_DETACH_N <= AX_DETACH_N_i AND NOT sup_comm_failure;

-------------------------------------------------------------------------------
-- Assignment of test ports
-------------------------------------------------------------------------------  
  TestSig : PROCESS (clk100, reset_n) IS
  BEGIN
    IF reset_n = '0' THEN
      TP_111            <= '0';
      TP_115            <= '0';
      TP_113            <= '0';
      TP_114            <= '0';
      toggleOnIRQ       <= '0';
      ticksSinceLastIRQ <= (OTHERS => '0');
    ELSIF clk100'event AND clk100 = '1' THEN
      IF irq_synch_pulse = '1' THEN
        toggleOnIRQ       <= NOT toggleOnIRQ;
        ticksSinceLastIRQ <= (OTHERS => '0');
      ELSE
        toggleOnIRQ       <= toggleOnIRQ;
        ticksSinceLastIRQ <= ticksSinceLastIRQ + '1';
      END IF;
      TP_111 <= irq_synch_pulse;
      TP_115 <= toggleOnIRQ;
      TP_113 <= TP_113_i;               -- = InverterTrigg(0)
      TP_114 <= TP_114_i;               -- = InverterTrigg(3)
    END IF;
  END PROCESS TestSig;
	
-------------------------------------------------------------------------------
-- Generating interrupt pulse synchronization
-------------------------------------------------------------------------------	
  irq_edge : PROCESS (clk100, reset_n) IS
  BEGIN
    IF reset_n = '0' THEN
      irq_synch_last    <= '0';
      irq_synch_pulse   <= '0';
    ELSIF clk100'event AND clk100 = '1' THEN
      IF (irq_synch_now = '1') AND (irq_synch_last = '0') THEN
        irq_synch_pulse <= '1';
      ELSE
        irq_synch_pulse <= '0';
      END IF;
      irq_synch_delay   <= SYS_IRQ;
		irq_synch_now     <= irq_synch_delay;
      irq_synch_last    <= irq_synch_now;
    END IF;
  END PROCESS irq_edge;		

-------------------------------------------------------------------------------
-- Component instatiations: 
-------------------------------------------------------------------------------	

  Communication_top_inst : Communication_top
    PORT MAP(
      reset_n         => reset_n,
      clk             => clk100,
      -- FSL ports
      -- DO NOT EDIT BELOW THIS LINE ---------------------
      -- Bus protocol ports, do not add or delete. 
		FSL_S_Clk       => FSL_S_Clk,
		FSL_S_Read      => FSL_S_Read,
		FSL_S_Data      => FSL_S_Data,
		FSL_S_Control   => FSL_S_Control,
		FSL_S_Exists    => FSL_S_Exists,
		FSL_M_Clk       => FSL_M_Clk,
		FSL_M_Write     => FSL_M_Write,
		FSL_M_Data      => FSL_M_Data,
		FSL_M_Control   => FSL_M_Control,
		FSL_M_Full      => FSL_M_Full,
      -- DO NOT EDIT ABOVE THIS LINE ---------------------
      -- DPM signals
      comm_dpm_web    => comm_dpm_web,
      comm_dpm_dinb   => comm_dpm_dinb,
      comm_dpm_doutb  => comm_dpm_doutb,
      comm_dpm_addrb  => comm_dpm_addrb
      );
  
  SlaveController_top_inst : SlaveController_top
    PORT MAP(
      reset_n                  => reset_n,
      clk                      => clk100,
      -- IRQ signals
      irq_level                => SYS_IRQ,
      irq_synch_pulse          => irq_synch_pulse,
      -- DPM signals
      comm_dpm_web             => comm_dpm_web,
      comm_dpm_dinb            => comm_dpm_dinb,
      comm_dpm_doutb           => comm_dpm_doutb,
      comm_dpm_addrb           => comm_dpm_addrb,
      pu_dpm_web               => pu_dpm_web,
      pu_dpm_dinb              => pu_dpm_dinb,
      pu_dpm_doutb             => pu_dpm_doutb,
      pu_dpm_addrb             => pu_dpm_addrb,
      pu_dpm_clkb              => clk100, 
      -- Memory ports
      reconfig_n               => RECONFIG_N,
      flashSelect              => FLASHSELECT,
      flashSelectMirror        => SELECTEDFLASH,
      flashMiso                => FLASH_MISO,
      flashMosi                => FLASH_MOSI,
      flashSpiCs_n             => FLASH_CS_N, 
      flashSpiClk              => FLASH_SCLK,
      eepromMiso               => PROM_MISO,
      eepromMosi               => PROM_MOSI,
      eepromSpiCs_n            => PROM_CS_N,
      eepromSpiClk             => PROM_SCK,
		-- PU internal signals
      deadTimeInverter1        => deadTimeInverter1,
      deadTimeInverter2        => deadTimeInverter2,
      deadTimeInverter3        => deadTimeInverter3,
      deadTimeInverter4        => deadTimeInverter4,
      deadTimeInverter5        => deadTimeInverter5,
      deadTimeInverter6        => deadTimeInverter6,
      puTrigg                  => puTrigg,
      puErrorTrigg             => puErrorTrigg,
      periodicStarted          => periodicStarted,
      activeNodes              => activeNodes,
      cfgDone                  => cfgDone,
      bleederTurnOnLevel       => bleederTurnOnLevel,
      bleederTurnOffLevel      => bleederTurnOffLevel,
      bleederTestLevel         => bleederTestLevel,
      dcSettleLevel            => dcSettleLevel,
      dcEngageLevel            => dcEngageLevel,
      dcDisengageLevel         => dcDisengageLevel,
      mainsVACType             => mainsVACType,
      noOfPhases               => noOfPhases,
      wdtTimeout               => wdtTimeout,
      powerBoardSupplyFail     => powerBoardSupplyFail_i,
      sampleADCEveryPeriod     => sampleADCEveryPeriod,      
      onlyIgnoreNodes          => onlyIgnoreNodes,
      cyclical_pu_data_updated => cyclical_pu_data_updated,
      pu_fdb_updated           => pu_fdb_updated,
      sup_comm_failure         => sup_comm_failure,
		-- Legacy signals
      startUpDone              => startUpDone
      );	

  PowerUnit_top_i0 : PowerUnit_top
    GENERIC MAP(
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP(
      Rst_n          => reset_n,
      Clk            => clk100,
      -- DPM signals
      Addrb          => pu_dpm_addrb,
      Dinb           => pu_dpm_dinb,
      Doutb          => pu_dpm_doutb,
      Web            => pu_dpm_web,
      -- PU PWM ports
      U_pwm_top_1     => U_pwm_top_1,
      U_pwm_bottom_1  => U_pwm_bottom_1,
      V_pwm_top_1     => V_pwm_top_1,
      V_pwm_bottom_1  => V_pwm_bottom_1,
      W_pwm_top_1     => W_pwm_top_1,
      W_pwm_bottom_1  => W_pwm_bottom_1,
      U_pwm_top_2     => U_pwm_top_2,
      U_pwm_bottom_2  => U_pwm_bottom_2,
      V_pwm_top_2     => V_pwm_top_2,
      V_pwm_bottom_2  => V_pwm_bottom_2,
      W_pwm_top_2     => W_pwm_top_2,
      W_pwm_bottom_2  => W_pwm_bottom_2,
      U_pwm_top_3     => U_pwm_top_3,
      U_pwm_bottom_3  => U_pwm_bottom_3,
      V_pwm_top_3     => V_pwm_top_3,
      V_pwm_bottom_3  => V_pwm_bottom_3,
      W_pwm_top_3     => W_pwm_top_3,
      W_pwm_bottom_3  => W_pwm_bottom_3,
      U_pwm_top_4     => U_pwm_top_4,
      U_pwm_bottom_4  => U_pwm_bottom_4,
      V_pwm_top_4     => V_pwm_top_4,
      V_pwm_bottom_4  => V_pwm_bottom_4,
      W_pwm_top_4     => W_pwm_top_4,
      W_pwm_bottom_4  => W_pwm_bottom_4,
      U_pwm_top_5     => U_pwm_top_5,
      U_pwm_bottom_5  => U_pwm_bottom_5,
      V_pwm_top_5     => V_pwm_top_5,
      V_pwm_bottom_5  => V_pwm_bottom_5,
      W_pwm_top_5     => W_pwm_top_5,
      W_pwm_bottom_5  => W_pwm_bottom_5,
      U_pwm_top_6     => U_pwm_top_6,
      U_pwm_bottom_6  => U_pwm_bottom_6,
      V_pwm_top_6     => V_pwm_top_6,
      V_pwm_bottom_6  => V_pwm_bottom_6,
      W_pwm_top_6     => W_pwm_top_6,
      W_pwm_bottom_6  => W_pwm_bottom_6,
      -- PU ADC ports
      ADC_UIN1        => ADC_UIN1,
      ADC_UOUT1       => ADC_UOUT1,
      ADC_SCLK1       => ADC_SCLK1,
      ADC_CS_N1       => ADC_CS_N1,
      ADC_VIN1        => OPEN, --ADC_VIN1,
      ADC_VOUT1       => ADC_VOUT1,
      ADC_UIN2        => ADC_UIN2,
      ADC_UOUT2       => ADC_UOUT2,
      ADC_SCLK2       => ADC_SCLK2,
      ADC_CS_N2       => ADC_CS_N2,
      ADC_VIN2        => OPEN, --ADC_VIN2,
      ADC_VOUT2       => ADC_VOUT2,
      ADC_UIN3        => ADC_UIN3,
      ADC_UOUT3       => ADC_UOUT3,
      ADC_SCLK3       => ADC_SCLK3,
      ADC_CS_N3       => ADC_CS_N3,
      ADC_VIN3        => OPEN, --ADC_VIN3,
      ADC_VOUT3       => ADC_VOUT3,
      ADC_UIN4        => ADC_UIN4,
      ADC_UOUT4       => ADC_UOUT4,
      ADC_SCLK4       => ADC_SCLK4,
      ADC_CS_N4       => ADC_CS_N4,
      ADC_VIN4        => OPEN, --ADC_VIN4,
      ADC_VOUT4       => ADC_VOUT4,
      ADC_UIN5        => ADC_UIN5,
      ADC_UOUT5       => ADC_UOUT5,
      ADC_SCLK5       => ADC_SCLK5,
      ADC_CS_N5       => ADC_CS_N5,
      ADC_VIN5        => OPEN, --ADC_VIN5,
      ADC_VOUT5       => ADC_VOUT5,
      ADC_UIN6        => ADC_UIN6,
      ADC_UOUT6       => ADC_UOUT6,
      ADC_SCLK6       => ADC_SCLK6,
      ADC_CS_N6       => ADC_CS_N6,
      ADC_VIN6        => OPEN, --ADC_VIN6,
      ADC_VOUT6       => ADC_VOUT6,
      -- PU related ports
      gateDriveTrip_n => gateDriveTrip_n,
      gateDriveFltClr => gateDriveFltClr,
      AX_DETACH_N     => AX_DETACH_N_i,
      bleederOn       => bleederOn_i,
      relayOn         => relayOn_i,
      GATEVOLT_17VOK  => GATEVOLT_17VOK,
      PWROK           => PWROK,
      phaseTrig       => phaseTrig,
      bleederFltClr   => bleederFltClr,
      bleederFltSD_n  => bleederFltSD_n,
      WDKick          => WDKick,
      -- SC internal signals
      deadTimeInverter1        => deadTimeInverter1,
      deadTimeInverter2        => deadTimeInverter2,
      deadTimeInverter3        => deadTimeInverter3,
      deadTimeInverter4        => deadTimeInverter4,
      deadTimeInverter5        => deadTimeInverter5,
      deadTimeInverter6        => deadTimeInverter6,
      puTrigg                  => puTrigg,
      puErrorTrigg             => puErrorTrigg,
      periodicStarted          => periodicStarted,
      activeNodes              => activeNodes,
      cfgDone                  => cfgDone,
      bleederTurnOnLevel       => bleederTurnOnLevel,
      bleederTurnOffLevel      => bleederTurnOffLevel,
      bleederTestLevel         => bleederTestLevel,
      dcSettleLevel            => dcSettleLevel,
      dcEngageLevel            => dcEngageLevel,
      dcDisengageLevel         => dcDisengageLevel,
      mainsVACType             => mainsVACType,
      noOfPhases               => noOfPhases,
      wdtTimeout               => wdtTimeout,
      powerBoardSupplyFail     => powerBoardSupplyFail_i,
      sampleADCEveryPeriod     => sampleADCEveryPeriod,
      onlyIgnoreNodes          => onlyIgnoreNodes,
      pu_data_updated          => cyclical_pu_data_updated,
      fdb_updated              => pu_fdb_updated,
      comm_failure             => sup_comm_failure,
      -- Test ports
      TP_201          => TP_111_i,
      TP_202          => TP_115_i,
      TP_203          => TP_113_i,
      TP_204          => TP_114_i,
      TP_205          => TP_117, --TRIP_SET
      TP_209          => OPEN
      );

end rtl;

