-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- Any unauthorised use, reproduction, distribution, or disclosure to third parties is 
-- strictly forbidden. ABB reserves all rights regarding Intellectual Property Rights.
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               IRQ Emulator Testbench Module
-- File name:           duf_tb/irq_emu_tb.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.03
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-11-18
-- **************************************************************************************
-- Related files:       duf_tb/duf_ip_top_tb.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- It is the emulator of interrupt generator.
-- 
-- **************************************************************************************
-- Revision 0.00 - 090930, CNABB/Ye-Ye Zhang
-- Created.
-- **************************************************************************************
-- Revision 0.01 - 090930, CNABB/Ye-Ye Zhang
-- Added irq interface.
-- * Added GENERIC parameters.
-- ************************************************************************************** 
-- Revision 0.02 - 091020, CNABB/Ye-Ye Zhang
-- Renamed from puc to duf.
-- * Replaced Power Unit Controller with Drive Unit Firmware.
-- ************************************************************************************** 
-- Revision 0.03 - 091118, CNABB/Ye-Ye Zhang
-- Revised GENERIC parameters.
-- * Added C_CLK_FREQ parameter.
-- * Changed from IRQ_TICKS to C_IRQ_NS.
-- * Added CONSTANT IRQ_TICKS.
-- ************************************************************************************** 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY irq_emu_tb IS
  GENERIC (
    C_CLK_FREQ  : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_IRQ_NS    : INTEGER RANGE 1 TO 1_000_000 := 63_000 -- 63,000ns = 63us
    );
  PORT(
    clk         : IN  STD_LOGIC;
	 rst         : IN  STD_LOGIC;
	 irq         : OUT STD_LOGIC
    );
END irq_emu_tb;

ARCHITECTURE BEHAVIOR OF irq_emu_tb IS
  
  CONSTANT IRQ_TICKS : INTEGER := (C_CLK_FREQ / 1_000_000 * C_IRQ_NS / 1_000);
  
  SIGNAL irq_i  : STD_LOGIC := '0';
  SIGNAL cnt_i  : INTEGER   := 1;

BEGIN

  irq <= irq_i;

  irq_gen: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
	   irq_i <= '0';
		cnt_i <= 1;
    ELSIF (clk'event AND clk = '1') THEN
	   IF (cnt_i = IRQ_TICKS) THEN
		  cnt_i <= 1;
		  irq_i <= '1';
		ELSE
		  cnt_i <= cnt_i + 1;
		  irq_i <= '0';
		END IF;
    END IF;
  END PROCESS;

END BEHAVIOR;



