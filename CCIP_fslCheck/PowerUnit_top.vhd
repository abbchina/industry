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
-- Title:               Power Unit top entity
-- File name:           PU_top.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.19
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		In progress
-- Date:		2009-04-06
-- **************************************************************************************
-- Related files:
--
-- **************************************************************************************
-- Functional description:
--
-- Instantiating a DP RAM (PU_DPM), GPIO, ADC i/f, RECTIFER CONTROLLER and INVERTERS.
-- Containing a state machine for shuffle of data in between SC_DPM and PU_DSP
-- and vice versa.
-- **************************************************************************************
-- 0.02: 080109 - SEROP/PRCB Magnus Tysell
-- * Correction of faulty PWM_ON feedback data. (pwm_cmd_C)
-- * Correction of faulty PWM_fail feedback data (TRIP1-6). 
-- **************************************************************************************	
-- 0.03: 080219 - SEROP/PRCB Magnus Tysell
-- * Added PWROK in entity.
-- **************************************************************************************	
-- 0.04: 080229 - SEROP/PRCB Magnus Tysell
-- * Node3 status feedback correction.
-- **************************************************************************************	
-- 0.05: 080310 - SEROP/PRCB Björn Nyqvist
-- * Added AC_V in feedback data. Removed BLEEDER_ON and RELAY_ON from GPIO_TOP
-- since they originates from rectCtrl.
-- **************************************************************************************	
-- 0.06: 080410 - SEROP/PRCB Magnus Tysell
-- * Corrected mapping of PWM_fail signals.
-- **************************************************************************************	
-- 0.07: 080527 - SEROP/PRCB Björn Nyqvist
-- * phaseTrig, bleederFltSD and bleederFltClr added to comply to rectCtrl P2.
-- **************************************************************************************	
-- 0.08: 080530 - SEROP/PRCB Magnus Tysell
-- * C_PWM_DEAD_BAND_TICKS (100MHz instead of C_PWM_DEAD_BAND_US
-- **************************************************************************************	
-- 0.09: 081209 - SEROP/PRCB Björn Nyqvist
-- * Configuration data signals from cdfUnit added. rectifier controller
-- updated to comply with MDU P2.
-- **************************************************************************************	
-- 0.10: 081210 - SEROP/PRCB Magnus Tysell
-- * Process for generating triggers to Inverters/ADCs added. Entity updated with 
-- PWM Delay times, active nodes.
-- **************************************************************************************	
-- 0.11: 090126 - SEROP/PRCB Björn Nyqvist
-- * Inverter undervoltage supervision removed due to AXC is noticed indirectly
-- by the "powerBoardSupplyFailure" feedback status bit.
-- **************************************************************************************	
-- 0.12: 090202 - SEROP/PRCB Magnus Tysell
-- * Many changes in ADC-block and in the process which copies the ADC data to the SC_DPM.
-- Due to erroneous ADC-data when running the drive unit with different PWM_DELAY_TIME values changes have 
-- been done in this block and in the underlying ADC-block to improve determinism.  
-- * Instead of copying the ADC data from the ADC-block to the PU_DPM and then from the PU_DPM to the SC_DPM, 
-- the data is now mapped with signals directly from the ADC-block into the process which copies the ADC data to the SC_DPM.
-- * The starting time (time from incomming puTrigg signal) for copy of data to the SC_DPM have been changed; it is now started 
-- on a fix time defined by a constant and is no longer depending on the timing in the underlying blocks/processes.
-- => This way of doing it requires that the value of the constant is composed with both Ethercat 
-- period time, MAX_PWM_DELAYTIME and the time for ADC sampling in mind. 
-- * By changing the way of providing PU_top with ADC data the interface to the rectifier control is changed:
-- Instead of using address decoding the "adcDataEnable" is now connected to "copyTrig" (one 100MHz pulse long) 
-- which indicates that valid ADC-data is valid. Depending on which nodes are addressed in this communication period; 
-- some ADC-data is "new" meaning sampled in this period and som data ADC-data is "old" meaning sampled in the previous communication period. 
-- => The rectifier control will have a trig puise each communication period (each 63us) but the data will be updated each other communication period (each 126us).
-- * Changed the trig pulses for ADCs. The ADC for a node will not be sampled when the node is switching.
-- **************************************************************************************	
-- 0.13: 090202 - SEROP/PRCB Björn Nyqvist
-- * rectCtrlFbkDataUpdated removed since bleederUnderVoltage detection is removed.
-- * Naming of RE_V1 and RE_V2 updated
-- **************************************************************************************	
-- 0.14: 090225 - SEROP/PRCB Magnus Tysell
-- * Part of fix for restart problem. Removed the copy-ctrl process. Generating the copyTrig 
-- based on the puTrig/puErrorTrig instead of pu_data_updated.
-- **************************************************************************************
-- 0.15: 090225 - SEROP/PRCB Björn Nyqvist
-- * C_PWM_DEAD_BAND_TICKS is removed since the configurable "deadTimeInverter"
-- vector is now used for each separate inverter. 
-- **************************************************************************************	
-- 0.16: 090323 - SEROP/PRCB Magnus Tysell
-- * Inverter feedback data updated. The location of inverterFailure and resetInverterFailureAck 
-- in the inverter status field. Now according to Robocat spec.
-- **************************************************************************************
-- 0.17: 090401 - SEROP/PRCB Björn Nyqvist
-- * pwmOn_d removed since it is now generated in Inverter_node_4K8K.vhd
-- * counterStarted, pwmOn_A, pwmOn_B, pwmOn_C, pwmSwFreq_A, pwmSwFreq_B, pwmSwFreq_C
-- are removed since they were not used.
-- * startBoostUp removed since it is now generated and used in Inverter_node_4K8K.vhd
-- **************************************************************************************
-- 0.18: 090401 - SEROP/PRCB Magnus Tysell
-- * PDI_IRQ_TO_PUTRIGG in the trigg process to compensate for the time the puTrigg pulse 
-- have been moved in time from the incoming pdi_irq.
-- * Changed some signal names. 
--   - data_read_ready_delay -> copySCtoPUDone. 
--   - fdbUpdated_i -> copyPUtoSCDone. 
-- **************************************************************************************     
-- 0.19: 090406 - SEROP/PRCB Magnus Tysell 
-- * pwmDelayTime changed from 16 to 14 bits.
-- * PWM_DELAY_TIME_N1-3 addresses added, used when copying from SC to PU. 
-- * PWMDelayTime1-6 removed from entity. Instead copied from SC DPM.
-- * activeNodes(5 downto 0) changed to activeNodes(6 downto 1) for use in PU_top 
--   with node number as index.
-- * inverterTrigg(5 downto 0) changed to inverterTrigg(6 downto 1) for use in PU_top 
--   with node number as index.
-- * adcTrigg(5 downto 0) changed to adcTrigg(6 downto 1) for use in PU_top 
--   with node number as index.
-- **************************************************************************************	
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY PowerUnit_top IS
  GENERIC (
    C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126 := 126;  -- PWM update rate in microseconds 
    C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6    := 5     -- PWM min pulse width time in microseconds
    );
  PORT (
    Rst_n           : IN  STD_LOGIC;
    Clk             : IN  STD_LOGIC;
    Addrb           : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    Dinb            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Doutb           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    Web             : OUT STD_LOGIC;
    pu_data_updated : IN  STD_LOGIC;
    fdb_updated     : OUT STD_LOGIC;
    comm_failure    : IN  STD_LOGIC;
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

    ADC_UIN1  : OUT STD_LOGIC;
    ADC_UOUT1 : IN  STD_LOGIC;
    ADC_SCLK1 : OUT STD_LOGIC;
    ADC_CS_N1 : OUT STD_LOGIC;
    ADC_VIN1  : OUT STD_LOGIC;
    ADC_VOUT1 : IN  STD_LOGIC;

    ADC_UIN2  : OUT STD_LOGIC;
    ADC_UOUT2 : IN  STD_LOGIC;
    ADC_SCLK2 : OUT STD_LOGIC;
    ADC_CS_N2 : OUT STD_LOGIC;
    ADC_VIN2  : OUT STD_LOGIC;
    ADC_VOUT2 : IN  STD_LOGIC;

    ADC_UIN3  : OUT STD_LOGIC;
    ADC_UOUT3 : IN  STD_LOGIC;
    ADC_SCLK3 : OUT STD_LOGIC;
    ADC_CS_N3 : OUT STD_LOGIC;
    ADC_VIN3  : OUT STD_LOGIC;
    ADC_VOUT3 : IN  STD_LOGIC;

    ADC_UIN4  : OUT STD_LOGIC;
    ADC_UOUT4 : IN  STD_LOGIC;
    ADC_SCLK4 : OUT STD_LOGIC;
    ADC_CS_N4 : OUT STD_LOGIC;
    ADC_VIN4  : OUT STD_LOGIC;
    ADC_VOUT4 : IN  STD_LOGIC;

    ADC_UIN5  : OUT STD_LOGIC;
    ADC_UOUT5 : IN  STD_LOGIC;
    ADC_SCLK5 : OUT STD_LOGIC;
    ADC_CS_N5 : OUT STD_LOGIC;
    ADC_VIN5  : OUT STD_LOGIC;
    ADC_VOUT5 : IN STD_LOGIC;

    ADC_UIN6  : OUT STD_LOGIC;
    ADC_UOUT6 : IN  STD_LOGIC;
    ADC_SCLK6 : OUT STD_LOGIC;
    ADC_CS_N6 : OUT STD_LOGIC;
    ADC_VIN6  : OUT STD_LOGIC;
    ADC_VOUT6 : IN  STD_LOGIC;

    gateDriveTrip_n      : IN  STD_LOGIC_VECTOR(6 DOWNTO 1);
    gateDriveFltClr      : OUT STD_LOGIC_VECTOR(6 DOWNTO 1);
    AX_DETACH_N          : OUT STD_LOGIC;
    bleederOn            : OUT STD_LOGIC;
    relayOn              : OUT STD_LOGIC;
    GATEVOLT_17VOK       : IN  STD_LOGIC;
    PWROK                : IN  STD_LOGIC;
    onlyIgnoreNodes      : IN  STD_LOGIC;
    WDKick               : OUT STD_LOGIC;
    phaseTrig            : IN  STD_LOGIC;
    bleederFltSD_n       : IN  STD_LOGIC;
    bleederFltClr        : OUT STD_LOGIC;
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
    deadTimeInverter1    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter2    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter3    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter4    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter5    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter6    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    wdtTimeout           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    powerBoardSupplyFail : OUT STD_LOGIC;
    sampleADCEveryPeriod : IN  STD_LOGIC;

    -- Temporary added test points
    TP_201 : OUT STD_LOGIC;
    TP_202 : OUT STD_LOGIC;
    TP_203 : OUT STD_LOGIC;
    TP_204 : OUT STD_LOGIC;
    TP_205 : OUT STD_LOGIC;
    TP_209 : OUT STD_LOGIC
    );
END PowerUnit_top;

ARCHITECTURE RTL OF PowerUnit_top IS

  CONSTANT DPRAM_WIDTH : NATURAL := 6;

-------------------------------------------------------------------------------
-- Following addresses are used to read data from SC_DPM in slave ctrl
-------------------------------------------------------------------------------
  CONSTANT UNIT_CMD_ADDR            : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0000";
  CONSTANT UNIT_REF_PAD_ADDR        : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0001";
  CONSTANT NODE_CMD_1_ADDR          : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0010";
  CONSTANT PWM_DELAY_TIME_N1        : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0011";    
  CONSTANT U_SWITCH_TIME_ADDR_N1    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0100";
  CONSTANT V_SWITCH_TIME_ADDR_N1    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0101";
  CONSTANT W_SWITCH_TIME_ADDR_N1    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0110";
  CONSTANT NODE_CMD_2_ADDR          : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_0111";
  CONSTANT PWM_DELAY_TIME_N2        : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1000";     
  CONSTANT U_SWITCH_TIME_ADDR_N2    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1001";
  CONSTANT V_SWITCH_TIME_ADDR_N2    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1010";
  CONSTANT W_SWITCH_TIME_ADDR_N2    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1011";
  CONSTANT NODE_CMD_3_ADDR          : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1100";
  CONSTANT PWM_DELAY_TIME_N3        : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1101";     
  CONSTANT U_SWITCH_TIME_ADDR_N3    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1110";
  CONSTANT V_SWITCH_TIME_ADDR_N3    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"00_1111";
  CONSTANT W_SWITCH_TIME_ADDR_N3    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"01_0000";
  CONSTANT RECT_REF_PAD1_ADDR       : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"01_0001";    
  CONSTANT RECT_REF_PAD2_ADDR       : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"01_0010";
  
-------------------------------------------------------------------------------
-- Following addresses are used for writing data to SC_DPM
-------------------------------------------------------------------------------
  CONSTANT DCVOL_ADDR           : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0000";
  CONSTANT NODE1_STATUS_ADDR    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0001";
  CONSTANT NODE1_PAD_ADDR       : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0010";    
  CONSTANT UCUR_N1_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0011";
  CONSTANT WCUR_N1_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0100";
  CONSTANT IGBT1_T_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0101";
  CONSTANT NODE2_STATUS_ADDR    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0110";
  CONSTANT NODE2_PAD_ADDR       : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_0111";     
  CONSTANT UCUR_N2_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1000";
  CONSTANT WCUR_N2_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1001";
  CONSTANT IGBT2_T_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1010";
  CONSTANT NODE3_STATUS_ADDR    : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1011";
  CONSTANT NODE3_PAD_ADDR       : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1100";     
  CONSTANT UCUR_N3_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1101";
  CONSTANT WCUR_N3_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1110";
  CONSTANT IGBT3_T_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"10_1111";
  CONSTANT RECTFIER_STATUS_ADDR : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"11_0000";
  CONSTANT RECTFIER_TEMP_ADDR   : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"11_0001";

  CONSTANT NUMBER_OF_READS  : NATURAL := 17;
  SIGNAL   nr_of_reads      : NATURAL RANGE 0 TO NUMBER_OF_READS+1;
  CONSTANT NUMBER_OF_WRITES : NATURAL := 15;
  SIGNAL   nr_of_writes     : NATURAL range 0 to NUMBER_OF_WRITES+1;

  CONSTANT NR_OF_NODES : INTEGER := 6; 

  TYPE STATE_TYPE IS (Idle, Switch);
  SIGNAL state : STATE_TYPE;
  TYPE ADDR_DECODER_STATE_TYPE IS (Idle, Copy_SCtoPU, Copy_PUtoSC);
  SIGNAL address_decoder_state : ADDR_DECODER_STATE_TYPE;

  SIGNAL web_A                           : STD_LOGIC;
  SIGNAL addrb_A                         : STD_LOGIC_VECTOR(5 DOWNTO 0);
  SIGNAL dinb_A, doutb_A                 : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL copySCtoPUDone  : STD_LOGIC;
  SIGNAL copyPUtoSCDone  : STD_LOGIC;
  SIGNAL node_numA, node_numB, node_numC : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL pwmOn       : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  SIGNAL pwmSwFreq   : std_logic_vector(NR_OF_NODES downto 1);

  -- Related to rectifier controller
  SIGNAL rectCtrlFbkData    : STD_LOGIC_VECTOR(15 DOWNTO 0);

  -- Related to the trigg process which generates the trigg pulses to the ADCs and the Inverters:
  CONSTANT DEFAULT_DELAY_TIME : INTEGER := 2100;
  CONSTANT ADJUSTING_SAMPLE   : INTEGER := 64;  -- Number of 100MHz ticks to adjust the ADC-sampling.

  SIGNAL ticksSinceEvent : INTEGER;
  SIGNAL adcTrigg        : STD_LOGIC_VECTOR((NR_OF_NODES) DOWNTO 1);
  SIGNAL inverterTrigg   : STD_LOGIC_VECTOR((NR_OF_NODES) DOWNTO 1);
  SIGNAL activeNodes_d   : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  
  TYPE pwmDelayTimeArray_t IS ARRAY (1 TO NR_OF_NODES) OF STD_LOGIC_VECTOR(13 DOWNTO 0);  
  SIGNAL pwmDelayTime            : pwmDelayTimeArray_t;
  SIGNAL inverterFailure         : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  SIGNAL resetInverterFailure    : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  SIGNAL resetInverterFailureAck : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  SIGNAL inverterShortCircuit    : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  SIGNAL inverterTempTooHigh     : STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
  SIGNAL inverterCmdRef_A        : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL inverterCmdRef_B        : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL inverterCmdRef_C        : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL powerBoardSupplyFail_i  : STD_LOGIC;
  SIGNAL mainsMissing            : STD_LOGIC;

  -- ADC signals:
  SIGNAL DC_V     : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL AC_V       : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL BL_V       : STD_LOGIC_VECTOR(11 DOWNTO 0);  
  SIGNAL RE_V1    : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL RE_V2    : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL rectTemp : STD_LOGIC_VECTOR(11 DOWNTO 0);
  TYPE ADC_array_t IS ARRAY (1 TO NR_OF_NODES) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL iPhaseU  : ADC_array_t;
  SIGNAL iPhaseV  : ADC_array_t;
  SIGNAL IGBTTemp : ADC_array_t;

  TYPE switchTime_array_t IS ARRAY (1 TO NR_OF_NODES) OF STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL swTimePhaseU : switchTime_array_t;
  SIGNAL swTimePhaseV : switchTime_array_t;
  SIGNAL swTimePhaseW : switchTime_array_t;

-- Signals used for generating the copyTrig pulse (ctrl process):
  CONSTANT START_COPY         : INTEGER := 3500;  -- Number of 100MHz ticks from "puTrigg/puErrorTrigg" to data copy to sc_dpm shall start. (3500 = 35us.)
  SIGNAL   copyTrig           : STD_LOGIC;
  CONSTANT PDI_IRQ_TO_PUTRIGG : INTEGER := 850;  -- Number of 100MHz ticks from incoming pdi_irq to puTrigg (state "correct_frame_received" in slavecontroller). (850 = 8,5us.)

-------------------------------------------------------------------------------
-- Component declarations
-------------------------------------------------------------------------------
  COMPONENT rectCtrl
    PORT(
      rst_n                : IN  STD_LOGIC;
      clk                  : IN  STD_LOGIC;
      -- DC_V, RE_V1 and RE_V2:
      adcDataEnable        : IN  STD_LOGIC;
      DC_V                 : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      AC_V                 : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      BL_V                 : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      RE_V1                : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      RE_V2                : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      -- MDU Power Board signals:
      phaseTrig            : IN  STD_LOGIC;
      powerBoardSupplyFail : IN  STD_LOGIC;
      bleederFltSD_n       : IN  STD_LOGIC;
      bleederFltClr        : OUT STD_LOGIC;
      bleederOn            : OUT STD_LOGIC;
      reOn                 : OUT STD_LOGIC;
      -- Feedback data interface:
      fbkData              : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      -- Configuration data:
      cfgDone              : IN  STD_LOGIC;
      bleederTurnOnLevel   : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTurnOffLevel  : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTestLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcSettleLevel        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcEngageLevel        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcDisengageLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      mainsVACType         : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      noOfPhases           : IN  STD_LOGIC;
      mainsMissing         : OUT STD_LOGIC
      );
  END COMPONENT rectCtrl;

  COMPONENT Inverter_Node_TOP
    GENERIC (
      C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  -- PWM update rate in microseconds 
      C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  -- PWM min pulse width time in microseconds
      );
    PORT
      (
        clk              : IN  STD_LOGIC;
        rst_n            : IN  STD_LOGIC;
        EtherCat_failure : IN  STD_LOGIC;
        Pwm_synch_pulse  : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);  -- synch signal input 
        u_switch_Node1   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        v_switch_Node1   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        w_switch_Node1   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        u_switch_Node2   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        v_switch_Node2   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        w_switch_Node2   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        u_switch_Node3   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        v_switch_Node3   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        w_switch_Node3   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0); 
        u_switch_Node4   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        v_switch_Node4   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        w_switch_Node4   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        u_switch_Node5   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        v_switch_Node5   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        w_switch_Node5   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0); 
        u_switch_Node6   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        v_switch_Node6   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        w_switch_Node6   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        
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

        deadTimeInverter1 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        deadTimeInverter2 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        deadTimeInverter3 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        deadTimeInverter4 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        deadTimeInverter5 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        deadTimeInverter6 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);

        inverterFailure         : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        resetInverterFailure    : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        resetInverterFailureAck : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        inverterShortCircuit    : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        inverterTempTooHigh     : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        gateDriveTrip_n         : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        gateDriveFltClr         : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        pwmOn                   : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        pwmSwFreq               : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
        puTrigg                 : IN  STD_LOGIC;
        powerBoardSupplyFail    : IN  STD_LOGIC;
        mainsMissing            : IN  STD_LOGIC;
        fbkDataUpd              : IN  STD_LOGIC
        );
  END COMPONENT;

  COMPONENT ADC_top
    PORT(
      Clk, Rst_n : IN  STD_LOGIC;
      Sync_irq   : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
      ADC_UIN1   : OUT STD_LOGIC;
      ADC_UOUT1  : IN  STD_LOGIC;
      ADC_SCLK1  : OUT STD_LOGIC;
      ADC_CS_N1  : OUT STD_LOGIC;
      ADC_VIN1   : OUT STD_LOGIC;
      ADC_VOUT1  : IN  STD_LOGIC;

      ADC_UIN2  : OUT STD_LOGIC;
      ADC_UOUT2 : IN  STD_LOGIC;
      ADC_SCLK2 : OUT STD_LOGIC;
      ADC_CS_N2 : OUT STD_LOGIC;
      ADC_VIN2  : OUT STD_LOGIC;
      ADC_VOUT2 : IN  STD_LOGIC;

      ADC_UIN3  : OUT STD_LOGIC;
      ADC_UOUT3 : IN  STD_LOGIC;
      ADC_SCLK3 : OUT STD_LOGIC;
      ADC_CS_N3 : OUT STD_LOGIC;
      ADC_VIN3  : OUT STD_LOGIC;
      ADC_VOUT3 : IN  STD_LOGIC;

      ADC_UIN4  : OUT STD_LOGIC;
      ADC_UOUT4 : IN  STD_LOGIC;
      ADC_SCLK4 : OUT STD_LOGIC;
      ADC_CS_N4 : OUT STD_LOGIC;
      ADC_VIN4  : OUT STD_LOGIC;
      ADC_VOUT4 : IN  STD_LOGIC;

      ADC_UIN5  : OUT STD_LOGIC;
      ADC_UOUT5 : IN  STD_LOGIC;
      ADC_SCLK5 : OUT STD_LOGIC;
      ADC_CS_N5 : OUT STD_LOGIC;
      ADC_VIN5  : OUT STD_LOGIC;
      ADC_VOUT5 : IN  STD_LOGIC;

      ADC_UIN6  : OUT STD_LOGIC;
      ADC_UOUT6 : IN  STD_LOGIC;
      ADC_SCLK6 : OUT STD_LOGIC;
      ADC_CS_N6 : OUT STD_LOGIC;
      ADC_VIN6  : OUT STD_LOGIC;
      ADC_VOUT6 : IN  STD_LOGIC;

      data_out_1u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_1v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_1u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_1v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      data_out_2u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_2v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_2u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_2v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      data_out_3u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_3v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_3u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_3v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      data_out_4u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_4v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_4u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_4v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      data_out_5u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_5v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_5u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_5v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      data_out_6u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_6v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_6u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_6v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
      );
  END COMPONENT;

COMPONENT GPIO_top
  PORT (
    Clk                  : IN  STD_LOGIC;
    Rst_n                : IN  STD_LOGIC;
    AX_DETACH_N          : OUT STD_LOGIC;
    GATEVOLT_17VOK       : IN  STD_LOGIC;
    PWROK                : IN  STD_LOGIC;
    WDKick               : OUT STD_LOGIC;
    powerBoardSupplyFail : OUT STD_LOGIC
    );
END COMPONENT;


BEGIN

  TP_201 <= '0';
  TP_202 <= '0';
  TP_203 <= inverterTrigg(1);
  TP_204 <= inverterTrigg(4);
  TP_205 <= '0';
  TP_209 <= '0';

 
  Addrb   <= addrb_A;                   -- Outgoing address to sc_dpm in the SlaveController block
  Dinb    <= dinb_A;                    -- Outgoing data to sc_dpm in the SlaveController block
  doutb_A <= Doutb;                     -- Incoming data from sc_dpm in the SlaveController block
  Web     <= web_A;                     -- Outgoing write enable to sc_dpm in the SlaveController block

  fdb_updated <= copyPUtoSCDone;

  powerBoardSupplyFail <= powerBoardSupplyFail_i;

  address_decoder :
  PROCESS(Clk, Rst_n)
  BEGIN
    IF (Rst_n = '0') THEN
      address_decoder_state <= Idle;
      nr_of_reads           <= 0;
      nr_of_writes          <= 0;
      copySCtoPUDone        <= '0';
      copyPUtoSCDone        <= '0';
      web_A                 <= '0';
      addrb_A               <= (OTHERS => 'Z');
      node_numA             <= (OTHERS => '0');
      node_numB             <= (OTHERS => '0');
      node_numC             <= (OTHERS => '0');
      pwmOn                 <= (OTHERS => '0');
      pwmSwFreq             <= (OTHERS => '0');
      dinb_A                <= (OTHERS => '0');
      resetInverterFailure  <= (OTHERS => '0');
      inverterCmdRef_A      <= (OTHERS => '0');
      inverterCmdRef_B      <= (OTHERS => '0');
      inverterCmdRef_C      <= (OTHERS => '0');
      swTimePhaseU          <= (OTHERS => (OTHERS => '0'));
      swTimePhaseV          <= (OTHERS => (OTHERS => '0'));
      swTimePhaseW          <= (OTHERS => (OTHERS => '0'));  
      pwmDelayTime          <= (OTHERS => (OTHERS => '0'));  
    ELSIF (Clk'event AND Clk = '1') THEN

      CASE address_decoder_state IS
        
        WHEN Idle =>          
          copySCtoPUDone  <= '0';
          copyPUtoSCDone  <= '0';
          web_A           <= '0';
          addrb_A         <= (OTHERS => 'Z');
          IF (pu_data_updated = '1') THEN  -- Cyclic PU_reference_data Updated
            address_decoder_state <= Copy_SCtoPU;
          ELSIF copyTrig = '1' THEN
            address_decoder_state <= Copy_PUtoSC;
          END IF;


        WHEN Copy_SCtoPU =>
          -- New reference data has been received.
          web_A  <= '0';
          -- Reading the data from the sc_dpm.
          -- Two states after the sc_dpm has been addressed the data is available.
          CASE nr_of_reads IS

            WHEN 0 =>
              addrb_A          <= NODE_CMD_1_ADDR;  
              nr_of_reads      <= nr_of_reads + 1;
            WHEN 1 =>
              addrb_A          <= NODE_CMD_2_ADDR;  
              nr_of_reads      <= nr_of_reads + 1;
            WHEN 2 =>
              addrb_A          <= NODE_CMD_3_ADDR;  
              node_numA        <= doutb_A(2 DOWNTO 0);  -- Reading the received Node number and sets the Node nr for "Node A".
              inverterCmdRef_A <= doutb_A;
              nr_of_reads      <= nr_of_reads + 1;
            WHEN 3 =>
              addrb_A          <= (OTHERS => 'Z');
              node_numB        <= doutb_A(2 DOWNTO 0);  -- Reading the received Node number and sets the Node nr for "Node A".
              inverterCmdRef_B <= doutb_A;
              nr_of_reads      <= nr_of_reads + 1;
              IF node_numA /= "000" THEN
                pwmOn(conv_integer(UNSIGNED(node_numA)))                <= inverterCmdRef_A(3);  -- Set PWM-enable for the specific node number (position node_numA in pwmOn vector).
                pwmSwFreq(conv_integer(UNSIGNED(node_numA)))            <= inverterCmdRef_A(4);  -- Set switching freq for the specific node number (position node_numA in pwmSwFreq vector).
                resetInverterFailure(conv_integer(UNSIGNED(node_numA))) <= inverterCmdRef_A(5);
              END IF;
            WHEN 4 =>
              addrb_A          <= U_SWITCH_TIME_ADDR_N1; 
              node_numC        <= doutb_A(2 DOWNTO 0);  -- Reading the received Node number and sets the Node nr for "Node C".
              inverterCmdRef_C <= doutb_A;
              nr_of_reads      <= nr_of_reads + 1;
              IF node_numB /= "000" THEN
                pwmOn(conv_integer(UNSIGNED(node_numB)))                <= inverterCmdRef_B(3);  -- Set PWM-enable for the specific node number (position node_numA in pwmOn vector).              
                pwmSwFreq(conv_integer(UNSIGNED(node_numB)))            <= inverterCmdRef_B(4);  -- Set switching freq for the specific node number (position node_numA in pwmSwFreq vector).
                resetInverterFailure(conv_integer(UNSIGNED(node_numB))) <= inverterCmdRef_B(5);
              END IF;
            WHEN 5 =>
              addrb_A     <= V_SWITCH_TIME_ADDR_N1;  
              nr_of_reads <= nr_of_reads + 1;
              IF node_numC /= "000" THEN
                pwmOn(conv_integer(UNSIGNED(node_numC)))                <= inverterCmdRef_C(3);  -- Set PWM-enable for the specific node number (position node_numA in pwmOn vector).
                pwmSwFreq(conv_integer(UNSIGNED(node_numC)))            <= inverterCmdRef_C(4);  -- Set switching freq for the specific node number (position node_numA in pwmSwFreq vector).     
                resetInverterFailure(conv_integer(UNSIGNED(node_numC))) <= inverterCmdRef_C(5);
              END IF;
            when 6 =>
              addrb_A     <= W_SWITCH_TIME_ADDR_N1;  
              -- Writing the U_SWITCH_TIME_ADDR_N1 to PU_DPM:
              IF node_numA /= "000" THEN
                swTimePhaseU(conv_integer(UNSIGNED(node_numA))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 7 =>
              addrb_A     <= U_SWITCH_TIME_ADDR_N2; 
              -- Writing the V_SWITCH_TIME_ADDR_N1 to PU_DPM:
              IF node_numA /= "000" THEN
                swTimePhaseV(conv_integer(UNSIGNED(node_numA))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 8 =>
              addrb_A     <= V_SWITCH_TIME_ADDR_N2;  
              --Writing the W_SWITCH_TIME_ADDR_N1 to PU_DPM:
              IF node_numA /= "000" THEN
                swTimePhaseW(conv_integer(UNSIGNED(node_numA))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 9 =>
              addrb_A     <= W_SWITCH_TIME_ADDR_N2; 
              -- Writing the U_SWITCH_TIME_ADDR_N2 to PU_DPM:
              IF node_numB /= "000" THEN
                swTimePhaseU(conv_integer(UNSIGNED(node_numB))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 10 =>
              addrb_A     <= U_SWITCH_TIME_ADDR_N3; 
              -- Writing the V_SWITCH_TIME_ADDR_N2 to PU_DPM:
              IF node_numB /= "000" THEN
                swTimePhaseV(conv_integer(UNSIGNED(node_numB))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 11 =>
              addrb_A     <= V_SWITCH_TIME_ADDR_N3;  
              -- Writing the W_SWITCH_TIME_ADDR_N2 to PU_DPM:
              IF node_numB /= "000" THEN
                swTimePhaseW(conv_integer(UNSIGNED(node_numB))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 12 =>
              addrb_A     <= W_SWITCH_TIME_ADDR_N3;  
              -- Writing the U_SWITCH_TIME_ADDR_N3 to PU_DPM:
              IF node_numC /= "000" THEN
                swTimePhaseU(conv_integer(UNSIGNED(node_numC))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 13 =>
              addrb_A     <= PWM_DELAY_TIME_N1;
              -- Writing the V_SWITCH_TIME_ADDR_N3 to PU_DPM:
              IF node_numC /= "000" THEN
                swTimePhaseV(conv_integer(UNSIGNED(node_numC))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 14 =>
              addrb_A     <= PWM_DELAY_TIME_N2;
              -- Writing the W_SWITCH_TIME_ADDR_N3 to PU_DPM:
              IF node_numC /= "000" THEN
                swTimePhaseW(conv_integer(UNSIGNED(node_numC))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 15 =>
              addrb_A     <= PWM_DELAY_TIME_N3;            
              IF node_numA /= "000" THEN
                pwmDelayTime(conv_integer(UNSIGNED(node_numA))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;
            when 16 =>    
              IF node_numB /= "000" THEN
                pwmDelayTime(conv_integer(UNSIGNED(node_numB))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;    
            when 17 =>    
              IF node_numC /= "000" THEN
                pwmDelayTime(conv_integer(UNSIGNED(node_numC))) <= doutb_A(13 downto 0);
              END IF;
              nr_of_reads <= nr_of_reads + 1;                
            when others =>
              addrb_A               <= (OTHERS => 'Z');
              address_decoder_state <= Idle;
              nr_of_reads           <= 0;
              copySCtoPUDone        <= '1'; 
          end case;
          
        when Copy_PUtoSC =>
          -- The ADC bock has updated the feedback data.
     	  -- Writes data to the sc_dpm that was
          -- read from the PU_DPM (or registers in the PU_logic) during previous cycle.
          case nr_of_writes is 

            WHEN 0 =>
              -- Copying U_current for Node1 data from PU-logic to sc_dpram:
              IF node_numA = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & iPhaseU(conv_integer(node_numA));
              END IF;
              addrb_A      <= UCUR_N1_ADDR;  -- B"10_0010"
              web_A        <= '1';
              nr_of_writes <= nr_of_writes + 1;
            WHEN 1 =>
              -- Copying W_current for Node1 data from PU_DPM to sc_dpram:
              IF node_numA = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & iPhaseV(conv_integer(node_numA));
              END IF;
              addrb_A      <= WCUR_N1_ADDR;  -- B"10_0011"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 2 =>
              -- Copying IGBT temperature for Node1 data from PU_DPM to sc_dpram:
              IF node_numA = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & IGBTTemp(conv_integer(node_numA));
              END IF;
              addrb_A      <= IGBT1_T_ADDR;  -- B"10_0100" 
              nr_of_writes <= nr_of_writes + 1;
            WHEN 3 =>
              -- Copying U_current for Node2 data from PU_DPM to sc_dpram:
              IF node_numB = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & iPhaseU(conv_integer(node_numB));
              END IF;
              addrb_A      <= UCUR_N2_ADDR;  -- B"10_0110"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 4 =>
              -- Copying W_current for Node2 data from PU_DPM to sc_dpram:
              IF node_numB = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & iPhaseV(conv_integer(node_numB));
              END IF;
              addrb_A      <= WCUR_N2_ADDR;  -- B"10_0111"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 5 =>
              -- Copying IGBT temperature for Node2 data from PU_DPM to sc_dpram:
              IF node_numB = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & IGBTTemp(conv_integer(node_numB));
              END IF;
              addrb_A      <= IGBT2_T_ADDR;  -- B"10_1000"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 6 =>
              -- Copying U_current for Node3 data from PU_DPM to sc_dpram:
              IF node_numC = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & iPhaseU(conv_integer(node_numC));
              END IF;
              addrb_A      <= UCUR_N3_ADDR;  -- B"10_1010"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 7 =>
              -- Copying W_current for Node3 data from PU_DPM to sc_dpram:
              IF node_numC = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & iPhaseV(conv_integer(node_numC));
              END IF;
              addrb_A      <= WCUR_N3_ADDR;  --B"10_1011"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 8 =>
              -- Copying IGBT temperature for Node3 data from PU_DPM to sc_dpram:
              IF node_numC = "000" THEN
                dinb_A     <= (OTHERS => '0');
              ELSE
                dinb_A     <= "0000" & IGBTTemp(conv_integer(node_numC));
              END IF;
              addrb_A      <= IGBT3_T_ADDR;  -- B"10_1100"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 9 =>
              -- Copying DC_V data from PU_DPM to sc_dpram:
              dinb_A       <= "0000" & DC_V;
              addrb_A      <= DCVOL_ADDR;  -- B"10_0000"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 10 =>
              -- Copying Rectifier Status data from rectCtrl to sc_dpram:
              dinb_A             <= rectCtrlFbkData;
              addrb_A            <= RECTFIER_STATUS_ADDR;  -- B"10_1101"
              nr_of_writes       <= nr_of_writes + 1;
            WHEN 11 =>
              -- Copying Rectifier Temperature data_d from PU_DPM to sc_dpram:
              dinb_A       <= "0000" & rectTemp;
              addrb_A      <= RECTFIER_TEMP_ADDR;  -- B"10_1110"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 12 =>
              -- Writing Node_1 status to sc_dpram:
              IF node_numA = "000" THEN
                dinb_A <= (OTHERS => '0');
              ELSE
                dinb_A(15 DOWNTO 0) <= "00000000" & inverterTempTooHigh(conv_integer(UNSIGNED(node_numA))) & inverterShortCircuit(conv_integer(UNSIGNED(node_numA)))
                                        & inverterFailure(conv_integer(UNSIGNED(node_numA))) & resetInverterFailureAck(conv_integer(UNSIGNED(node_numA))) 
                                        & pwmOn(conv_integer(UNSIGNED(node_numA))) & node_numA;
              END IF;
              addrb_A      <= NODE1_STATUS_ADDR;  -- B"10_0001"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 13 =>
              -- Writing Node_2 status to sc_dpram:
              IF node_numB = "000" THEN
                dinb_A <= (OTHERS => '0');
              ELSE
                dinb_A(15 DOWNTO 0) <= "00000000" & inverterTempTooHigh(conv_integer(UNSIGNED(node_numB))) & inverterShortCircuit(conv_integer(UNSIGNED(node_numB)))
                                        & inverterFailure(conv_integer(UNSIGNED(node_numB))) & resetInverterFailureAck(conv_integer(UNSIGNED(node_numB)))
                                        & pwmOn(conv_integer(UNSIGNED(node_numB))) & node_numB;
              end if;
              addrb_A      <= NODE2_STATUS_ADDR;  -- B"10_0101"
              nr_of_writes <= nr_of_writes + 1;
            WHEN 14 =>
              -- Writing Node_3 status to sc_dpram:
              if node_numC = "000" then
                dinb_A <= (others => '0');
              else
                dinb_A(15 downto 0) <=  "00000000" & inverterTempTooHigh(conv_integer(unsigned(node_numC))) & inverterShortCircuit(conv_integer(unsigned(node_numC))) 
                                        & inverterFailure(conv_integer(UNSIGNED(node_numC))) & resetInverterFailureAck(conv_integer(UNSIGNED(node_numC))) 
                                        & pwmOn(conv_integer(unsigned(node_numC))) & node_numC;
              end if;
              addrb_A      <= NODE3_STATUS_ADDR;  -- B"10_1001"
              nr_of_writes <= nr_of_writes + 1;
            WHEN OTHERS =>
              addrb_A               <= (OTHERS => 'Z');
              web_A                 <= '0';
              address_decoder_state <= Idle;
              nr_of_writes          <= 0;
              copyPUtoSCDone  <= '1';
          END CASE;
      END CASE;
    END IF;
  END PROCESS;
	
	
  -------------------------------------------------------------------------------
  -- Trigg generate process for ADCs and Inverters
  -------------------------------------------------------------------------------
  -- Purpose: Generating trigg pulses for each node, both ADC-trigg
  -- and Inverter-trigg. When a node is addressed, an Inverter-trigg indicating 
  -- the PWM center point for that node is generated based on the PWM Delay 
  -- Time for that node. An ADC-trigg for that node is also generated with a constant 
  -- offset from the Inverter-trigg.
  -- If a node is not addressed it will not get an Inverter trigg. But the ADC-trigg
  -- that node is still generated, but at a Default Delay Time from the puTrigg.
  -- The process is counting the time (in 100MHz ticks) from the last puTrigg .
  trigg :
  PROCESS (Clk, Rst_n)
  BEGIN
    IF (Rst_n = '0') THEN
      ticksSinceEvent <= 0;
      adcTrigg        <= (OTHERS => '0');
      inverterTrigg   <= (OTHERS => '0');
      activeNodes_d   <= (OTHERS => '0'); 
      copyTrig        <= '0'; 
    ELSIF (Clk'event AND Clk = '1') THEN
      -- counter is reset by the puTrigg (pdi_irq OR error_trigg).      
      IF puTrigg = '1' THEN
        ticksSinceEvent <= PDI_IRQ_TO_PUTRIGG;
      ElSIF puErrorTrigg = '1' THEN
        ticksSinceEvent <= conv_integer(wdtTimeout);
      ELSE
        ticksSinceEvent <= ticksSinceEvent + 1;
      END IF;
      -- If periodic process data communication is started 
      -- the triggers for the ADCs and the Inverters are generated:  
      IF periodicStarted = '1' THEN
        FOR i IN 1 TO NR_OF_NODES LOOP
          IF ticksSinceEvent = conv_integer(PWMDelayTime(i)) AND activeNodes(i) = '1' THEN
            inverterTrigg(i) <= NOT comm_failure;
          ELSE
            inverterTrigg(i) <= '0';
          END IF;
          IF ticksSinceEvent = (conv_integer(PWMDelayTime(i)) - ADJUSTING_SAMPLE) AND activeNodes(i) = '1' THEN
            -- Current node is active, ADC for this node will be sampled on the
            -- center of PWM pulse.
            adcTrigg(i) <= '1';
            activeNodes_d(i)  <= activeNodes(i);  
          ELSIF ticksSinceEvent = DEFAULT_DELAY_TIME AND activeNodes(i) = '0' THEN
            -- Current node is not active
            activeNodes_d(i)  <= activeNodes(i);
            IF activeNodes_d(i) = '0' OR sampleADCEveryPeriod = '1' THEN
              -- The node has not been active during the last two communication
              -- periods, therefore the ADCs will be sampled each 63 us tick.
              -- (The node is never switching)
              adcTrigg(i) <= '1';
            ELSE
              -- The node was active on previous tick, thus the node is switching
              -- in this period and no sampling of ADC will be done for this node.
              adcTrigg(i) <= '0';              
            END IF;
          ELSE
            adcTrigg(i) <= '0';
          END IF;
        END LOOP;
        -- Start copy data from PU to SC.
        IF ticksSinceEvent = START_COPY THEN
          copyTrig <= '1';
        ELSE
          copyTrig <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS;           


-------------------------------------------------------------------------------
-- Component instantiations:
-------------------------------------------------------------------------------
  rectCtrl_i0 : rectCtrl
    PORT MAP (
      rst_n                => rst_n,
      clk                  => clk,
      -- ADC signals:
      adcDataEnable        => copyTrig,
      DC_V                 => DC_V,
      AC_V                 => AC_V,
      BL_V                 => BL_V,
      RE_V1                => RE_V1,
      RE_V2                => RE_V2,
      -- MDU power board signals:
      phaseTrig            => phaseTrig,
      powerBoardSupplyFail => powerBoardSupplyFail_i,
      bleederFltSD_n       => bleederFltSD_n,
      bleederFltClr        => bleederFltClr,
      bleederOn            => bleederOn,
      reOn                 => relayOn,
      -- Feedback data:
      fbkData              => rectCtrlFbkData,
      -- Configuration signals:
      cfgDone              => cfgDone,
      bleederTurnOnLevel   => bleederTurnOnLevel,
      bleederTurnOffLevel  => bleederTurnOffLevel,
      bleederTestLevel     => bleederTestLevel,
      dcSettleLevel        => dcSettleLevel,
      dcEngageLevel        => dcEngageLevel,
      dcDisengageLevel     => dcDisengageLevel,
      mainsVACType         => mainsVACType,
      noOfPhases           => noOfPhases,
      mainsMissing         => mainsMissing
      );

  INVERTER : Inverter_Node_TOP
    GENERIC MAP(
      C_CLK_FREQ                 => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US       => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US   => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP(
      Clk              => Clk,
      Rst_n            => Rst_n,
      EtherCat_failure => comm_failure,
      Pwm_synch_pulse  => inverterTrigg,
      u_switch_Node1   => swTimePhaseU(1),
      v_switch_Node1   => swTimePhaseV(1),
      w_switch_Node1   => swTimePhaseW(1),
      u_switch_Node2   => swTimePhaseU(2),
      v_switch_Node2   => swTimePhaseV(2),
      w_switch_Node2   => swTimePhaseW(2),
      u_switch_Node3   => swTimePhaseU(3),
      v_switch_Node3   => swTimePhaseV(3),
      w_switch_Node3   => swTimePhaseW(3),
      u_switch_Node4   => swTimePhaseU(4),
      v_switch_Node4   => swTimePhaseV(4),
      w_switch_Node4   => swTimePhaseW(4),
      u_switch_Node5   => swTimePhaseU(5),
      v_switch_Node5   => swTimePhaseV(5),
      w_switch_Node5   => swTimePhaseW(5),
      u_switch_Node6   => swTimePhaseU(6),
      v_switch_Node6   => swTimePhaseV(6),
      w_switch_Node6   => swTimePhaseW(6),
      U_pwm_top_1      => U_pwm_top_1,
      U_pwm_bottom_1   => U_pwm_bottom_1,
      V_pwm_top_1      => V_pwm_top_1,
      V_pwm_bottom_1   => V_pwm_bottom_1,
      W_pwm_top_1      => W_pwm_top_1,
      W_pwm_bottom_1   => W_pwm_bottom_1,

      U_pwm_top_2    => U_pwm_top_2,
      U_pwm_bottom_2 => U_pwm_bottom_2,
      V_pwm_top_2    => V_pwm_top_2,
      V_pwm_bottom_2 => V_pwm_bottom_2,
      W_pwm_top_2    => W_pwm_top_2,
      W_pwm_bottom_2 => W_pwm_bottom_2,

      U_pwm_top_3    => U_pwm_top_3,
      U_pwm_bottom_3 => U_pwm_bottom_3,
      V_pwm_top_3    => V_pwm_top_3,
      V_pwm_bottom_3 => V_pwm_bottom_3,
      W_pwm_top_3    => W_pwm_top_3,
      W_pwm_bottom_3 => W_pwm_bottom_3,

      U_pwm_top_4    => U_pwm_top_4,
      U_pwm_bottom_4 => U_pwm_bottom_4,
      V_pwm_top_4    => V_pwm_top_4,
      V_pwm_bottom_4 => V_pwm_bottom_4,
      W_pwm_top_4    => W_pwm_top_4,
      W_pwm_bottom_4 => W_pwm_bottom_4,

      U_pwm_top_5    => U_pwm_top_5,
      U_pwm_bottom_5 => U_pwm_bottom_5,
      V_pwm_top_5    => V_pwm_top_5,
      V_pwm_bottom_5 => V_pwm_bottom_5,
      W_pwm_top_5    => W_pwm_top_5,
      W_pwm_bottom_5 => W_pwm_bottom_5,

      U_pwm_top_6    => U_pwm_top_6,
      U_pwm_bottom_6 => U_pwm_bottom_6,
      V_pwm_top_6    => V_pwm_top_6,
      V_pwm_bottom_6 => V_pwm_bottom_6,
      W_pwm_top_6    => W_pwm_top_6,
      W_pwm_bottom_6 => W_pwm_bottom_6,

      deadTimeInverter1 => deadTimeInverter1,
      deadTimeInverter2 => deadTimeInverter2,
      deadTimeInverter3 => deadTimeInverter3,
      deadTimeInverter4 => deadTimeInverter4,
      deadTimeInverter5 => deadTimeInverter5,
      deadTimeInverter6 => deadTimeInverter6,

      inverterFailure         => inverterFailure,
      resetInverterFailure    => resetInverterFailure,
      resetInverterFailureAck => resetInverterFailureAck,
      inverterShortCircuit    => inverterShortCircuit,
      inverterTempTooHigh     => inverterTempTooHigh,
      gateDriveTrip_n         => gateDriveTrip_n,
      gateDriveFltClr         => gateDriveFltClr,
      pwmOn                   => pwmOn,
      pwmSwFreq               => pwmSwFreq,
      puTrigg                 => puTrigg,
      powerBoardSupplyFail    => powerBoardSupplyFail_i,
      mainsMissing            => mainsMissing,
      fbkDataUpd              => copyPUtoSCDone
      );

  ADC : ADC_top
    PORT MAP(
      Clk      => Clk,
      Rst_n    => Rst_n,
      Sync_irq => adcTrigg,

      ADC_UIN1  => ADC_UIN1,
      ADC_UOUT1 => ADC_UOUT1,
      ADC_SCLK1 => ADC_SCLK1,
      ADC_CS_N1 => ADC_CS_N1,
      ADC_VIN1  => ADC_VIN1,
      ADC_VOUT1 => ADC_VOUT1,

      ADC_UIN2  => ADC_UIN2,
      ADC_UOUT2 => ADC_UOUT2,
      ADC_SCLK2 => ADC_SCLK2,
      ADC_CS_N2 => ADC_CS_N2,
      ADC_VIN2  => ADC_VIN2,
      ADC_VOUT2 => ADC_VOUT2,

      ADC_UIN3  => ADC_UIN3,
      ADC_UOUT3 => ADC_UOUT3,
      ADC_SCLK3 => ADC_SCLK3,
      ADC_CS_N3 => ADC_CS_N3,
      ADC_VIN3  => ADC_VIN3,
      ADC_VOUT3 => ADC_VOUT3,

      ADC_UIN4  => ADC_UIN4,
      ADC_UOUT4 => ADC_UOUT4,
      ADC_SCLK4 => ADC_SCLK4,
      ADC_CS_N4 => ADC_CS_N4,
      ADC_VIN4  => ADC_VIN4,
      ADC_VOUT4 => ADC_VOUT4,

      ADC_UIN5  => ADC_UIN5,
      ADC_UOUT5 => ADC_UOUT5,
      ADC_SCLK5 => ADC_SCLK5,
      ADC_CS_N5 => ADC_CS_N5,
      ADC_VIN5  => ADC_VIN5,
      ADC_VOUT5 => ADC_VOUT5,

      ADC_UIN6  => ADC_UIN6,
      ADC_UOUT6 => ADC_UOUT6,
      ADC_SCLK6 => ADC_SCLK6,
      ADC_CS_N6 => ADC_CS_N6,
      ADC_VIN6  => ADC_VIN6,
      ADC_VOUT6 => ADC_VOUT6,

      data_out_1u0 => iPhaseU(1),
      data_out_1v0 => iPhaseV(1),
      data_out_1u1 => BL_V,
      data_out_1v1 => IGBTTemp(1),

      data_out_2u0 => iPhaseU(2),
      data_out_2v0 => iPhaseV(2),
      data_out_2u1 => DC_V,
      data_out_2v1 => IGBTTemp(2),

      data_out_3u0 => iPhaseU(3),
      data_out_3v0 => iPhaseV(3),
      data_out_3u1 => AC_V,
      data_out_3v1 => IGBTTemp(3),

      data_out_4u0 => iPhaseU(4),
      data_out_4v0 => iPhaseV(4),
      data_out_4u1 => RE_V1,
      data_out_4v1 => IGBTTemp(4),

      data_out_5u0 => iPhaseU(5),
      data_out_5v0 => iPhaseV(5),
      data_out_5u1 => RE_V2,
      data_out_5v1 => IGBTTemp(5),

      data_out_6u0 => iPhaseU(6),
      data_out_6v0 => iPhaseV(6),
      data_out_6u1 => rectTemp,
      data_out_6v1 => IGBTTemp(6)
      );

  GPIO : GPIO_top
    PORT MAP (
      Clk                  => Clk,
      Rst_n                => Rst_n,
      AX_DETACH_N          => AX_DETACH_N,
      GATEVOLT_17VOK       => GATEVOLT_17VOK,
      PWROK                => PWROK,
      WDKick               => WDKick,
      powerBoardSupplyFail => powerBoardSupplyFail_i
      );


end RTL;

