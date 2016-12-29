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
-- Title:               Read and controll block for GPIO signals.
-- File name:           GPIO_TOP.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:   0
-- Revision:         0.10
-- Prepared by:      Björn Nyqvist
-- Status:           Updated
-- Date:             2009-02-18
-- **************************************************************************************
-- References:
-- 
-- **************************************************************************************
-- Functional description:
--
--
-- **************************************************************************************
-- changes:
-- 0.2: Maty 080219: Added: AX_reset trigger on PWROK. 
-- **************************************************************************************
-- changes:
-- 0.3: BjNy 080307: BLEEDER_ON and RELAY_ON deleted since they orginates in
-- the rectifier controller unit.
-- **************************************************************************************
-- 0.4: MaTy 080411: TRIP signals inverted for correct levels in RoboCAT. 
-- **************************************************************************************
-- 0.5: MaTy 080514: 
-- * Changed signal "AX_Reset" to "AX_detach". 
-- * Added functionality for 50kHz kick for external watchdog. Input signal WDOK
-- is connected to AX_detach. Added WDOK and WDKick in the entity.
-- **************************************************************************************
-- 0.6: MaTy 080818: 
-- * Latching the incomming trip signals and error signals. The data is reset once every 63us. 
-- * Added AX_DETACHED and PWR_NOK in fdb data. Correct polarity.
-- * New signal lowGateVolt in fdb data instead of 18VOK. Now correct polarity.
-- * Added medianfilter to PWROK and 18VOK, to make the AX_DETACH functionality more robust.
-- **************************************************************************************
-- 0.7: MaTy 081006: 
-- * Changed signal names: DR_TRIP#_N, GATEVOLT_17VOK. WDOK removed.
-- **************************************************************************************
-- 0.8: BjNy 081210: 
-- * DR_TRIP#_N, FAULT_CLEAR moved to PU unit.
-- **************************************************************************************
-- 0.9: MaTy 081211: 
-- * gateDriveFltClrStart removed. 
-- **************************************************************************************
-- 0.10: BjNy 090217
-- * Lowpass filter added instead of the decimation fifo filter
-- **************************************************************************************
-- 0.11:  MaTy 090402
-- * PU dpm read/write logic removed. Not needed because the powerBoardSupplyFail output 
-- is mapped directly to the slavecontroller block.
-- **************************************************************************************
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY GPIO_top IS
  PORT (
    Clk                  : IN  STD_LOGIC;
    Rst_n                : IN  STD_LOGIC;
    AX_DETACH_N          : OUT STD_LOGIC;
    GATEVOLT_17VOK       : IN  STD_LOGIC;
    PWROK                : IN  STD_LOGIC;
    WDKick               : OUT STD_LOGIC;
    powerBoardSupplyFail : OUT STD_LOGIC
    );
END GPIO_top;

ARCHITECTURE RTL OF GPIO_top IS

  COMPONENT medianFilter IS
    GENERIC (
      nrOfFlipFlops  : INTEGER;
      setRstPolarity : STRING
      );
    PORT(
      rst_n     : IN  STD_LOGIC;
      clk       : IN  STD_LOGIC;
      din       : IN  STD_LOGIC;
      dout      : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT lowPassFilter
    GENERIC (
      decimationFactor : INTEGER;
      setRstPolarity   : STRING;
      filterLength     : INTEGER
      );
    PORT(
      rst_n          : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      din            : IN  STD_LOGIC;
      dout           : OUT STD_LOGIC
      );
  END COMPONENT lowPassFilter;
  
  -- Watchdog signals:
  CONSTANT WD_KICK_FREQ   : INTEGER := 50_000;  -- Hz
  CONSTANT WD_KICK_PERIOD : INTEGER := (100_000_000/WD_KICK_FREQ);  -- WD_KICK_PERIOD in number of 100MHz ticks.
  SIGNAL   WDCounter      : INTEGER;
  SIGNAL   WDKick_i       : STD_LOGIC;

  SIGNAL PWROK_i1       : STD_LOGIC;
  SIGNAL PWROK_i2       : STD_LOGIC;
  SIGNAL PLUS_18UVL0_i1 : STD_LOGIC;
  SIGNAL PLUS_18UVL0_i2 : STD_LOGIC;
  SIGNAL AX_DETACH_N_i   : STD_LOGIC;
  

BEGIN 

-------------------------------------------------------------------------------
-- Median filter instantiation - filter glitches on the MPU input signals.
-- Furthermore, some filtering are done in order to avoid false values when
-- the analog signal switching level.
-------------------------------------------------------------------------------
  medianFilter_i0 : medianFilter
    GENERIC MAP(
      nrOfFlipFlops  => 5,
      setRstPolarity => "high"
      )
    PORT MAP(
      rst_n          => rst_n,
      clk            => clk,
      din            => PWROK,
      dout           => PWROK_i1
      );

  medianFilter_i1 : medianFilter
    GENERIC MAP(
      nrOfFlipFlops  => 5,
      setRstPolarity => "high"
      )
    PORT MAP(
      rst_n          => rst_n,
      clk            => clk,
      din            => GATEVOLT_17VOK,
      dout           => PLUS_18UVL0_i1
      );

   lowPassFilter_i0 : lowPassFilter
     GENERIC MAP(
       decimationFactor => 100,
       setRstPolarity   => "high",
       filterLength     => 64 
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => PWROK_i1,
       dout           => PWROK_i2
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
       din            => PLUS_18UVL0_i1,
       dout           => PLUS_18UVL0_i2
       );
   
   -----------------------------------------
   -- Generates the watchdog kick. 
   -- WDKick is 50% high.
   -- (AX_detach_n in will be active
   -- on internal reset.)
   -----------------------------------------
  WDKick <=WDKick_i;
	
  AX_DETACH_N_i <= PWROK_i2 AND PLUS_18UVL0_i2;
  AX_DETACH_N   <= AX_DETACH_N_i;

  powerBoardSupplyFail <= NOT PLUS_18UVL0_i2;

  ExtWatchdog : PROCESS (clk, Rst_n) IS
  BEGIN
    IF Rst_n = '0' THEN
      WDKick_i    <= '0';
      WDCounter   <= (WD_KICK_PERIOD / 2) -1;
    ELSIF clk'event AND clk = '1' THEN
      IF WDCounter = 0 THEN
        WDCounter <= (WD_KICK_PERIOD / 2) -1;
        WDKick_i  <= NOT WDKick_i;
      ELSE
        WDCounter <= WDCounter - 1;
      END IF;
    END IF;
  END PROCESS ExtWatchdog;

END RTL;
