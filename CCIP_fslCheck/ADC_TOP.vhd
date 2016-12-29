------------------------------------------------------------------------------
-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
------------------------------------------------------------------------------
-- Filename:          ADC_top.vhd
-- VHDL Standard:     VHDL'93
-- Written by:        Yang Gao
-- Status:            Edited
-- Date:                   2.56us each conversion  
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
-- **************************************************************************
-- 0.01: 090218 - SEROP/PRCB Magnus Tysell
-- Copy of ADC data to PU_dpm removed. Replaced with direct mapping of signals 
-- to PU_top.
-- *************************************************************************
-- 0.02: 090406 - SEROP/PRCB Magnus Tysell	
-- * Sync_irq(5 downto 0) changed to Sync_irq(6 downto 1).
-- ***************************************************************************

------------------------------------------------------------------------------
--Library Section
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_unsigned.ALL;
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Entity Section
------------------------------------------------------------------------------

ENTITY ADC_top IS

  PORT(
    Clk, Rst_n : IN  STD_LOGIC;
    Sync_irq   : IN  STD_LOGIC_VECTOR(6 DOWNTO 1);
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

  ATTRIBUTE SIGIS        : STRING;
  ATTRIBUTE SIGIS OF Clk : SIGNAL IS "CLK";

END ADC_top;
  
ARCHITECTURE rtl OF ADC_top IS

  COMPONENT SH_ctrl is
  port(
    clk         : IN  STD_LOGIC;
    rst_n       : IN  STD_LOGIC;
    sync_trig   : IN  STD_LOGIC;
    spi_uin     : IN  STD_LOGIC;
    spi_uout    : OUT STD_LOGIC;
    spi_clk     : OUT STD_LOGIC;
    spi_cs_n    : OUT STD_LOGIC;
    spi_vin     : IN  STD_LOGIC;
    spi_vout    : OUT STD_LOGIC;
    data_out_u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
  );
  END COMPONENT;
    
BEGIN
  
  ADC_AXIS_1 : SH_ctrl
    PORT MAP (
      clk         => Clk,
      rst_n       => Rst_n,
      sync_trig   => Sync_irq(1),
      spi_uin     => ADC_UOUT1,
      spi_uout    => ADC_UIN1,
      spi_clk     => ADC_SCLK1,
      spi_cs_n    => ADC_CS_N1,
      spi_vin     => ADC_VOUT1,
      spi_vout    => ADC_VIN1,
      data_out_u0 => data_out_1u0,
      data_out_v0 => data_out_1v0,
      data_out_u1 => data_out_1u1,
      data_out_v1 => data_out_1v1
      );

  ADC_AXIS_2 : SH_ctrl
    PORT MAP (
      clk         => Clk,
      rst_n       => Rst_n,
      sync_trig   => Sync_irq(2),
      spi_uin     => ADC_UOUT2,
      spi_uout    => ADC_UIN2,
      spi_clk     => ADC_SCLK2,
      spi_cs_n    => ADC_CS_N2,
      spi_vin     => ADC_VOUT2,
      spi_vout    => ADC_VIN2,
      data_out_u0 => data_out_2u0,
      data_out_v0 => data_out_2v0,
      data_out_u1 => data_out_2u1,
      data_out_v1 => data_out_2v1
      );

  ADC_AXIS_3 : SH_ctrl
    PORT MAP (
      clk         => Clk,
      rst_n       => Rst_n,
      sync_trig   => Sync_irq(3),
      spi_uin     => ADC_UOUT3,
      spi_uout    => ADC_UIN3,
      spi_clk     => ADC_SCLK3,
      spi_cs_n    => ADC_CS_N3,
      spi_vin     => ADC_VOUT3,
      spi_vout    => ADC_VIN3,
      data_out_u0 => data_out_3u0,
      data_out_v0 => data_out_3v0,
      data_out_u1 => data_out_3u1,
      data_out_v1 => data_out_3v1
      );

  ADC_AXIS_4 : SH_ctrl
    PORT MAP (
      clk         => Clk,
      rst_n       => Rst_n,
      sync_trig   => Sync_irq(4),
      spi_uin     => ADC_UOUT4,
      spi_uout    => ADC_UIN4,
      spi_clk     => ADC_SCLK4,
      spi_cs_n    => ADC_CS_N4,
      spi_vin     => ADC_VOUT4,
      spi_vout    => ADC_VIN4,
      data_out_u0 => data_out_4u0,
      data_out_v0 => data_out_4v0,
      data_out_u1 => data_out_4u1,
      data_out_v1 => data_out_4v1
      );

  ADC_AXIS_5 : SH_ctrl
    PORT MAP (
      clk         => Clk,
      rst_n       => Rst_n,
      sync_trig   => Sync_irq(5),
      spi_uin     => ADC_UOUT5,
      spi_uout    => ADC_UIN5,
      spi_clk     => ADC_SCLK5,
      spi_cs_n    => ADC_CS_N5,
      spi_vin     => ADC_VOUT5,
      spi_vout    => ADC_VIN5,
      data_out_u0 => data_out_5u0,
      data_out_v0 => data_out_5v0,
      data_out_u1 => data_out_5u1,
      data_out_v1 => data_out_5v1
      );

  ADC_AXIS_6 : SH_ctrl
    PORT MAP (
      clk         => Clk,
      rst_n       => Rst_n,
      sync_trig   => Sync_irq(6),
      spi_uin     => ADC_UOUT6,
      spi_uout    => ADC_UIN6,
      spi_clk     => ADC_SCLK6,
      spi_cs_n    => ADC_CS_N6,
      spi_vin     => ADC_VOUT6,
      spi_vout    => ADC_VIN6,
      data_out_u0 => data_out_6u0,
      data_out_v0 => data_out_6v0,
      data_out_u1 => data_out_6u1,
      data_out_v1 => data_out_6v1
      );
END ARCHITECTURE rtl;

