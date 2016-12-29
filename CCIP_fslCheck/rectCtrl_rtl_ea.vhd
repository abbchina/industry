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
-- Title:               Rectifier Controller top module
-- File name:           rectCtrl_rtl_a.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		1.6
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		Approved
-- Date:		2009-02-09
-- **************************************************************************************
-- References:
-- 1. Design Specification Rectifier Controller 3HAC030434-001
-- 2. RoboCat Protocol User Guide
-- 3. TRS MINK Power and Capacitor Unit 3HAC027503-001
-- 4. EK Gränssnittsbeskrivning rev D
-- **************************************************************************************
-- Functional description:
--
-- This component is located in the PU_top module. ADC data is fetched
-- from the PU DPM whereas the reference and feedback data is located in the
-- slave controller DPM. The control outputs is connected to the top level in
-- order to manage bleeder and relays on the Power Unit board. 
--
-- In General, the purpose of the rectCtrl is to supervise AC (incoming mains)
-- as well as the DC link. For further info, see ref 1.
--
-- See respectively process description for furter information of their functionality.
--
-- bleederFltSD and phaseTrig are asynchronous signals and therefore they
-- need to be synchronized to avoid metastabiliy. All other signals are fully
-- synchronous to the 100 MHz clock.
--
-- Abbreviations:
-- LV = Low Voltage supply
-- HV = High Voltage supply
-- 1P = 1 phase system
-- 3P = 3 phase system
-- GD = Gate Drive
-- MDU = Main Drive Unit
--
-- **************************************************************************************
-- changes:
-- 1.1 080411 BjNy: Scale factor of 4.8 on AC_V and DC_V inserted.
-- 1.2 080522 BjNy: Updated to conform to MDU P1.1.
-- 1.3 081205 BjNy: Completely updated to conform to MDU P2.
-- 1.4 090118 BjNy: Bleeder gate driver undervoltage removed.
-- 1.5 091221 BjNy: engageBleederForTest separated from bleedeOn feedback to DSP.
-- 1.6 090209 BjNy: The process collectAdcData updated to reflect the changes
-- in PU TOP. fbkDataUpd removed, only used for underVoltage detection.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY rectCtrl IS
  PORT(
    rst_n                : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;  --100MHz
    -- ADC interface:
    adcDataEnable        : IN  STD_LOGIC;
    DC_V                 : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    AC_V                 : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    BL_V                 : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    RE_V1                : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);    
    RE_V2                : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    -- Inrush circuit control signals:
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
END rectCtrl;

ARCHITECTURE rtl OF rectCtrl IS

  CONSTANT TIMEOUT_20us : INTEGER := 2000;
  
  SIGNAL debugMode : STD_LOGIC;  -- Set to '0' for synthesis

  -- For generation of the 100 KHz clk enable pulse
  SIGNAL clk100KHzEn             : STD_LOGIC;
  SIGNAL clkCnt                  : NATURAL RANGE 0 TO 999;
  ATTRIBUTE SIGIS                : STRING;
  ATTRIBUTE SIGIS of clk100KHzEn : SIGNAL IS "CLK";

  -- Related to "collect adc data" process
  SIGNAL dcVoltage          : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL acVoltage          : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL bleederVoltage          : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL re1Voltage         : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL re2Voltage         : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL adcDataUpdated : STD_LOGIC;
 
  -- Related to mains supervision
  SIGNAL phaseTrig_i1   : STD_LOGIC;
  SIGNAL phaseTrig_i2   : STD_LOGIC;  
  SIGNAL mainsMissing_i : STD_LOGIC;
  SIGNAL phaseMissing   : STD_LOGIC;
  SIGNAL freqError      : STD_LOGIC;  

  -- Related to the "Bleeder gate driver supervision" process
  SIGNAL bleederFltSD_n_i1   : STD_LOGIC;
  SIGNAL bleederFltSD_n_i2   : STD_LOGIC;  
  SIGNAL bleederShortCircuit : STD_LOGIC;
  SIGNAL startClrPulse       : STD_LOGIC;
  TYPE clrGateDrive_t IS (idle, generateClrPulse);
  SIGNAL clrGateDriverState  : clrGateDrive_t;
  SIGNAL clrPulseTImer       : NATURAL RANGE 0 TO 2000;
  SIGNAL cnt                 : NATURAL RANGE 0 TO 3;

  -- Related to bleeder resistor
  SIGNAL bleederOn_i          : STD_LOGIC;  

  -- Feedback status bits
  SIGNAL relayFailure       : STD_LOGIC;
  SIGNAL bleederOpen        : STD_LOGIC;
  SIGNAL reOn_i             : STD_LOGIC;
  SIGNAL inrushActive       : STD_LOGIC;
  SIGNAL inrushResistorOpen : STD_LOGIC;
  SIGNAL fbkData_i          : STD_LOGIC_VECTOR(15 DOWNTO 0);

-------------------------------------------------------------------------------
-- Component declarations
-------------------------------------------------------------------------------
  COMPONENT mainsSupervision
    PORT(
      rst_n            : IN  STD_LOGIC;
      clk              : IN  STD_LOGIC;
      clk100KHzEn      : IN  STD_LOGIC;
      phaseTrig_i      : IN  STD_LOGIC;
      noOfPhases       : IN  STD_LOGIC;
      cfgDone          : IN  STD_LOGIC;
      newAcSampleEnable: IN  STD_LOGIC;
      mainsVACType     : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      dcVoltage        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      acVoltage        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcDisengageLevel : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      mainsMissing     : OUT STD_LOGIC;
      phaseMissing     : OUT STD_LOGIC;
      freqError        : OUT STD_LOGIC;
      -- Temp added test signals
      acIsCrap         : OUT STD_LOGIC
      );
  END COMPONENT mainsSupervision;

  COMPONENT inrushSupervision
    PORT(
      debugMode           : IN  STD_LOGIC;
      rst_n               : IN  STD_LOGIC;
      clk                 : IN  STD_LOGIC;
      clk100KHzEn         : IN  STD_LOGIC;
      cfgDone             : IN  STD_LOGIC;
      mainsVACType        : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
      bleederTurnOnLevel  : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTurnOffLevel : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederTestLevel    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcSettleLevel       : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcEngageLevel       : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcDisengageLevel    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      dcVoltage           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      bleederVoltage      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      re1Voltage          : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      re2Voltage          : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
      adcDataUpdated       : IN  STD_LOGIC;
      mainsMissing        : IN  STD_LOGIC;
      bleederShortCircuit : IN  STD_LOGIC;
      relayFailure        : OUT STD_LOGIC;
      bleederOpen         : OUT STD_LOGIC;
      inrushResistorOpen  : OUT STD_LOGIC;
      inrushActive        : OUT STD_LOGIC;      
      reOn                : OUT STD_LOGIC;
      bleederOn           : OUT STD_LOGIC
      );
  END COMPONENT inrushSupervision;

  COMPONENT medianFilter
    GENERIC (
      nrOfFlipFlops  : INTEGER;
      setRstPolarity : STRING
      );
    PORT(
      rst_n          : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      din            : IN  STD_LOGIC;
      dout           : OUT STD_LOGIC
      );
  END COMPONENT medianFilter;
  
  COMPONENT lowPassFilter
    GENERIC (
      decimationFactor  : INTEGER;
      setRstPolarity : STRING;
      filterLength   : INTEGER
      );
    PORT(
      rst_n          : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      din            : IN  STD_LOGIC;
      dout           : OUT STD_LOGIC
      );
  END COMPONENT lowPassFilter;
  
-------------------------------------------------------------------------------

BEGIN

  debugMode <= '0';
  
-------------------------------------------------------------------------------
-- Component instantiations
-------------------------------------------------------------------------------
  mainsSupervision_i0 : mainsSupervision
    PORT MAP(
      rst_n            => rst_n,
      clk              => clk,
      clk100KHzEn      => clk100KHzEn,
      phaseTrig_i      => phaseTrig_i2,
      noOfPhases       => noOfPhases,
      cfgDone          => cfgDone,
      newAcSampleEnable=> adcDataUpdated,
      mainsVACType     => mainsVACType,
      dcVoltage        => dcVoltage,
      acVoltage        => acVoltage,
      dcDisengageLevel => dcDisengageLevel,
      mainsMissing     => mainsMissing_i,
      phaseMissing     => phaseMissing,
      freqError        => freqError,
      acIsCrap         => OPEN
      );

  inrushSupervision_i0 : inrushSupervision
    PORT MAP(
      debugMode           => debugMode,
      rst_n               => rst_n,
      clk                 => clk,
      clk100KHzEn         => clk100KHzEn,
      cfgDone             => cfgDone,
      mainsVACType        => mainsVACType,
      bleederTurnOnLevel  => bleederTurnOnLevel,
      bleederTurnOffLevel => bleederTurnOffLevel,
      bleederTestLevel    => bleederTestLevel,      
      dcSettleLevel       => dcSettleLevel,
      dcEngageLevel       => dcEngageLevel,
      dcDisengageLevel    => dcDisengageLevel,
      dcVoltage           => dcVoltage,
      bleederVoltage      => bleederVoltage,
      re1Voltage          => re1Voltage,
      re2Voltage          => re2Voltage,
      adcDataUpdated       => adcDataUpdated,
      mainsMissing        => mainsMissing_i,
      bleederShortCircuit => bleederShortCircuit,
      relayFailure        => relayFailure,
      bleederOpen         => bleederOpen,
      inrushResistorOpen  => inrushResistorOpen,
      inrushActive        => inrushActive,      
      reOn                => reOn_i,
      bleederOn            => bleederOn_i
      );

   medianFilter_i0 : medianFilter
     GENERIC MAP(
       nrOfFlipFlops  => 5,
       setRstPolarity => "high"
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => phaseTrig,
       dout           => phaseTrig_i1
      );

   lowPassFilter_i0 : lowPassFilter
     GENERIC MAP(
       decimationFactor => 100,
       setRstPolarity   => "high",
       filterLength     => 32 
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => phaseTrig_i1,
       dout           => phaseTrig_i2
       );

   medianFilter_i1 : medianFilter
     GENERIC MAP(
       nrOfFlipFlops  => 5,
       setRstPolarity => "high"
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => bleederFltSD_n,
       dout           => bleederFltSD_n_i1
      );
  
   lowPassFilter_i1 : lowPassFilter
     GENERIC MAP(
       decimationFactor => 100,
       setRstPolarity   => "high",
       filterLength     => 64 
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => bleederFltSD_n_i1,
       dout           => bleederFltSD_n_i2
       );

-------------------------------------------------------------------------------
-- 100 KHz clock enable generation
-------------------------------------------------------------------------------
  -- Purpose: There are several large counters in the design and to reduce the
  -- number of utlized flip-flops this 100 KHz clock enable signal is created.
   
   gen100KHz : PROCESS (clk, rst_n)
   BEGIN 
     IF rst_n = '0' THEN
       clkCnt <= 0;
       clk100KHzEn <= '0';
     ELSIF clk'event AND clk = '1' THEN
       IF clkCnt = 999 THEN
         clkCnt <= 0;
         clk100KHzEn <= '1';
       ELSE
         clkCnt <= clkCnt + 1;
         clk100KHzEn <= '0';
       END IF;
     END IF;
   END PROCESS gen100KHz;
   
-------------------------------------------------------------------------------
-- Logic for "COLLECT ADC DATA"
-------------------------------------------------------------------------------
  -- Purpose: Collects voltage values for DC_V, RE_V1 and RE_V2 which is
  -- transmitted from the ADC interface. On each new sample an enable signal is
  -- trigged during one clock period. 

  collectAdcData : PROCESS (clk, rst_n) IS
  BEGIN
    IF rst_n = '0' THEN
      dcVoltage  <= (OTHERS => '0');
      acVoltage  <= (OTHERS => '0');
      bleederVoltage  <= (OTHERS => '0');
      re1Voltage <= (OTHERS => '0');
      re2Voltage <= (OTHERS => '0');
      adcDataUpdated  <= '0';
     ELSIF clk'event AND clk = '1' THEN
      IF adcDataEnable = '1' THEN
        adcDataUpdated <= '1';
        dcVoltage  <= DC_V;
        acVoltage  <= AC_V;
        bleederVoltage <= BL_V;
        re1Voltage <= RE_V1;
        re2Voltage <= RE_V2;
      ELSE
        adcDataUpdated <= '0';
            dcVoltage  <= dcVoltage;
            acVoltage  <= acVoltage;
            bleederVoltage <= bleederVoltage;
            re1Voltage <= re1Voltage;
            re2Voltage <= re2Voltage;
      END IF;
    END IF;
  END PROCESS collectAdcData;

-------------------------------------------------------------------------------
-- Bleeder Gate Driver supervision
-------------------------------------------------------------------------------
  -- Purpose: If a short circuit fault is detected and report to AXC.
  -- bleederUnderVoltage not reported since AXC is noticed on unit level by
  -- the "powerBoardSupplyFail" status bit.
   
   bleederGateDriverSupervision : PROCESS (clk, rst_n)
   BEGIN 
     IF rst_n = '0' THEN
       bleederFltClr <= '1';
       bleederShortCircuit <= '0';
       startClrPulse <= '0';
       clrGateDriverState <= idle;
       clrPulseTimer <= 0;
     ELSIF clk'event AND clk = '1' THEN
       bleederFltClr <= '0';           
       
       IF mainsMissing_i = '1' THEN
         -- Clear error when mains contactor is opened
         IF bleederShortCircuit = '1' THEN
           startClrPulse <= '1';
         ELSE
           startClrPulse <= '0';
         END IF;
       ELSIF bleederFltSD_n_i2 = '0' AND powerBoardSupplyFail = '0' THEN
         bleederShortCircuit <= '1';
       ELSE
         bleederShortCircuit <= bleederShortCircuit;
       END IF;

       CASE clrGateDriverState IS
         WHEN idle =>
           clrPulseTimer <= 0;           
           IF startClrPulse = '1' THEN
             clrGateDriverState <= generateClrPulse;
             bleederShortCircuit <= '0';
             startClrPulse <= '0';
           ELSE
             clrGateDriverState <= idle;
           END IF;
           
         WHEN generateClrPulse => 
           IF clrPulseTimer = TIMEOUT_20us THEN
             bleederFltClr <= '0';
             clrGateDriverState <= idle;
           ELSE
             clrPulseTimer <= clrPulseTimer + 1;
             bleederFltClr <= '1';
           END IF;
           
         WHEN OTHERS =>
           clrGateDriverState <= idle;
           
       END CASE;
     END IF;
   END PROCESS bleederGateDriverSupervision;
       
-------------------------------------------------------------------------------
-- Assign feedback data to the DSP
-------------------------------------------------------------------------------  
-- Purpose: Assign rectifier status as feedback data to the DSP. The feedback
-- data ends up in the DPM (located in slave controller) at address X"2D".

  assignFbkData : PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      fbkData <= X"02C0";
    ELSIF clk'event AND clk = '1' THEN
      fbkData <= fbkData_i;
    END IF;
  END PROCESS assignFbkData;
  
-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
  reOn      <= reOn_i;
  bleederOn <= bleederOn_i WHEN bleederShortCircuit = '0' ELSE '0';
  mainsMissing <= mainsMissing_i;
   
  fbkData_i <= "00000" & reOn_i & inrushActive & freqError & phaseMissing & 
               mainsMissing_i & relayFailure & inrushResistorOpen & 
               '0' & bleederShortCircuit & bleederOpen & bleederOn_i;

  
END ARCHITECTURE rtl;

