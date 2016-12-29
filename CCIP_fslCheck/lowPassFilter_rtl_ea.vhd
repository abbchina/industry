-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Low pass filter
-- File name:           lowPassFilter_rtl_ea.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.1
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		Edited
-- Date:		2009-02-03
-- **************************************************************************************
-- References:
-- 1.
-- **************************************************************************************
-- Functional description:
-- The purpose of the low pass filter is to suppress high frequent disturbances.
--
-- Three generics are utlized:
-- decimationFactor, default is "100"
-- decimationFactor specifies how much the input signal shall be decimated.
--
-- setRstPolarity, default is "low".
-- setRstpolarity specifies if the filter output shall be reset to low or high.
--
-- filterLength, default is "64".
-- filterLength specifies how many samples taken into account to generate the output
-- **************************************************************************************
-- changes:
--
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY lowPassFilter IS
  GENERIC (
    decimationFactor : INTEGER := 100;
    setRstPolarity   : STRING  := "high";
    filterLength     : INTEGER := 64
    );
  PORT(
    rst_n            : IN  STD_LOGIC;
    clk              : IN  STD_LOGIC;
    din              : IN  STD_LOGIC;
    dout             : OUT STD_LOGIC
    );
END lowPassFilter;

ARCHITECTURE rtl OF lowPassFilter IS

  SIGNAL filterCnt    : NATURAL RANGE 0 TO filterLength - 1;
  SIGNAL dinDecimated : STD_LOGIC;

  -- For generation of the 100 KHz clk enable pulse
  SIGNAL clkEn    : STD_LOGIC;
  SIGNAL clkEn_d  : STD_LOGIC;
  SIGNAL clkCnt   : NATURAL RANGE 0 TO decimationFactor - 1;
  ATTRIBUTE SIGIS : STRING;
  ATTRIBUTE SIGIS OF clkEn : SIGNAL IS "CLK";
  

BEGIN

-------------------------------------------------------------------------------
-- Clock enable generation
-------------------------------------------------------------------------------
  -- Purpose: Generate a clock enable signal used to decimate the input signal.   
  genClkEn : PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      clkCnt   <= 0;
      clkEn    <= '0';
      clkEn_d  <= '0';
    ELSIF clk'event AND clk = '1' THEN
      clkEn_d  <= clkEn;
      IF clkCnt = (decimationFactor - 1) THEN
        clkCnt <= 0;
        clkEn  <= '1';
      ELSE
        clkCnt <= clkCnt + 1;
        clkEn  <= '0';
      END IF;
    END IF;
  END PROCESS genClkEn;

-------------------------------------------------------------------------------
-- Low pass filter logic
-------------------------------------------------------------------------------   
   -- Purpose: The filter input is decimated and then a counter is utilized to
   -- keep track of how many zeros and ones that has been detected. The value
   -- of the counter is then used to create a hysteresis of the filter output. 
   filter : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       IF setRstPolarity = "high" THEN
         dout         <= '1';
         filterCnt    <= filterLength - 1;
         dinDecimated <= '1';
       ELSE
         dout         <= '0';
         filterCnt    <= 0;
         dinDecimated <= '0';
       END IF;
     ELSIF clk'event AND clk = '1' THEN

       -- Perform decimation of the input
       IF clkEn = '1' THEN
         dinDecimated <= din;
       ELSE
         dinDecimated <= dinDecimated;
       END IF;

       -- Update the filter counter depending on input and create a hysteresis
       -- on the filter output
       IF clkEn_d = '1' THEN
         IF dinDecimated = '1' THEN
           IF filterCnt = (filterLength - 1) THEN
             filterCnt <= filterCnt;
             dout <= '1';
           ELSE
             filterCnt <= filterCnt + 1;
           END IF;
         ELSE
           IF filterCnt = 0 THEN
             filterCnt <= filterCnt;
             dout <= '0';
           ELSE
             filterCnt <= filterCnt - 1;
           END IF;
         END IF;
       ELSE
         filterCnt <= filterCnt;
       END IF;
     END IF;
   END PROCESS filter;

END ARCHITECTURE rtl;

