-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Median filter
-- File name:           medianFilter_ea.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.1
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		Edited
-- Date:		2008-05-01
-- **************************************************************************************
-- References:
-- 1.
-- **************************************************************************************
-- Functional description:
-- The purpose of the median filter is to suppress glitches. This is done by
-- calculating the mean value of a number of input samples.
--
-- E.g. the input is clocked five times and if three or more flipflop outputs are '1',
-- the filter mean output is '1'.
--
-- Two generics are utlized:
-- nrOfFlipflops, default is "5".
-- nrOfFlipflops specifies the length of the filter. Only odd numbers must be used.
--
-- setRstPolarity, default is "low".
-- setRstpolarity specifies if the filter output shall be reset to low or high.
-- **************************************************************************************
-- changes:
--
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY medianFilter IS
  GENERIC (
    nrOfFlipFlops  : INTEGER := 5;
    setRstPolarity : STRING  := "low"
    );
  PORT(
    rst_n          : IN  STD_LOGIC;
    clk            : IN  STD_LOGIC;
    din            : IN  STD_LOGIC;
    dout           : OUT STD_LOGIC
    );
END medianFilter;

ARCHITECTURE rtl OF medianFilter IS

  TYPE filterArray_t IS ARRAY (nrOfFlipFlops - 1 DOWNTO 0) OF STD_LOGIC;
  SIGNAL shiftIn : filterArray_t;

BEGIN

  filter : PROCESS (clk, rst_n)
    VARIABLE tmp : INTEGER := 0;
    VARIABLE sum : INTEGER := 0;    
  BEGIN
    IF rst_n = '0' THEN
      IF setRstPolarity = "high" THEN
        dout    <= '1';
        shiftIn <= (OTHERS => '1');
      ELSE
        dout    <= '0';
        shiftIn <= (OTHERS => '0');
      END IF;
      tmp := 0;
      sum := 0;
    ELSIF clk'event AND clk = '1' THEN
      shiftIn(0) <= din;
      shiftIn(nrOfFlipFlops - 1 DOWNTO 1) <= shiftIn(nrOfFlipFlops - 2 DOWNTO 0);

      FOR i IN 0 TO nrOfFlipFlops LOOP
        IF i < nrOfFlipFlops THEN
          tmp := conv_integer(shiftIn(i));
          sum := sum + tmp;
        ELSE
          IF sum > ((nrOfFlipFlops - 1)/2) THEN
            dout <= '1';
            sum := 0;
          ELSE
            dout <= '0';
            sum := 0;
          END IF;
        END IF;
      END LOOP;
    END IF;
  END PROCESS filter;

END ARCHITECTURE rtl;

