-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- Any unauthorised use, reproduction, distribution, or disclosure to third parties is 
-- strictly forbidden. ABB reserves all rights regarding Intellectual Property Rights.
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Clock and Reset Emulator Testbench Module
-- File name:           duf_tb/clk_rst_tb.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.05
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-11-18
-- **************************************************************************************
-- Related files:       duf_tb/duf_ip_top_tb.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- It is the emulator of clock and reset generator.
-- 
-- **************************************************************************************
-- Revision 0.01 - 090311, CNABB/Dream-Shengping Tu
-- Modify the names of the signals according to the vhdl code convention.
-- ************************************************************************************** 
-- Revision 0.03 - 090930, CNABB/Ye-Ye Zhang
-- Revised clk and rst parameters.
-- * Renamed reset to rst, reset_i to rst_i.
-- * Added GENERIC parameters.
-- ************************************************************************************** 
-- Revision 0.04 - 091020, CNABB/Ye-Ye Zhang
-- Renamed from puc to duf.
-- * Replaced Power Unit Controller with Drive Unit Firmware.
-- ************************************************************************************** 
-- Revision 0.05 - 091118, CNABB/Ye-Ye Zhang
-- Revised parameters.
-- * Removed generic parameters.
-- * Changed clocks and powerup_reset parameters.
-- ************************************************************************************** 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY clk_rst_tb IS
  GENERIC(
    C_CLK_FREQ  : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_RST_NS    : INTEGER RANGE 1 TO 1_000_000 := 200
    );
  PORT(
    clk_100  : OUT STD_LOGIC;
	 clk_125  : OUT STD_LOGIC;
    rst      : OUT STD_LOGIC
    );
END clk_rst_tb;

ARCHITECTURE BEHAVIOR OF clk_rst_tb IS
  
  CONSTANT CLK_HALF_PERIOD : INTEGER := (1_000_000_000 / C_CLK_FREQ / 2); -- ns
  CONSTANT RST_NS : NATURAL := C_RST_NS; -- ns
  
  SIGNAL clk_100_i : STD_LOGIC := '0';
  SIGNAL clk_125_i : STD_LOGIC := '0';
  SIGNAL rst_i : STD_LOGIC := '1';

BEGIN

  clk_100 <= clk_100_i;
  clk_125 <= clk_125_i;
  rst <= rst_i;

  clock_100: PROCESS
  BEGIN
    WHILE (TRUE) LOOP
      clk_100_i <= NOT clk_100_i;
--      WAIT FOR CLK_HALF_PERIOD ns;
      WAIT FOR 5 ns;  -- 5ns for 100MHz, 4ns for 125MHz 
    END LOOP;
  END PROCESS;

  clock_125: PROCESS
  BEGIN
    WHILE (TRUE) LOOP
      clk_125_i <= NOT clk_125_i;
--      WAIT FOR CLK_HALF_PERIOD ns;
      WAIT FOR 4 ns;  -- 5ns for 100MHz, 4ns for 125MHz 
    END LOOP;
  END PROCESS;

  powerup_reset: PROCESS
  BEGIN
    rst_i    <= '1';
--    WAIT FOR RST_NS ns;
    WAIT FOR 200 ns;
    rst_i    <= '0';
    WAIT;
  END PROCESS;  

END BEHAVIOR;



