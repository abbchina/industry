-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- Any unauthorised use, reproduction, distribution, or disclosure to third parties is 
-- strictly forbidden. ABB reserves all rights regarding Intellectual Property Rights.
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Drive Unit Firmware IP Testbench Top Module
-- File name:           duf_tb/duf_ip_top_tb.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.07
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-11-18
-- **************************************************************************************
-- Related files:       Testbench for IP core top
--                      duf_tb/fsl_emu_tb.vhd
--                      duf_tb/irq_emu_tb.vhd
--                      duf_tb/clk_rst_tb.vhd
--                      duf_top/duf_ip_top.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- It is the top testbench of Drive Unit Firmware IP.
-- 
-- **************************************************************************************
-- Revision 0.01 - 090311, CNABB/Dream-Shengping Tu
-- Modify the names of the signals according to the vhdl code convention.
-- ************************************************************************************** 
-- Revision 0.03 - 090929, CNABB/Ye-Ye Zhang
-- Replaced enc interface with puc interface.
-- * Removed puc_emu_tb related signals.
-- * Set SELECTEDFLASH to '1'.
-- ************************************************************************************** 
-- Revision 0.04 - 090930, CNABB/Ye-Ye Zhang
-- Added irq emulator component.
-- * Added component irq_emu_tb.
-- * Set SYS_IRQ to irq_i.
-- ************************************************************************************** 
-- Revision 0.05 - 091020, CNABB/Ye-Ye Zhang
-- Renamed from puc to duf.
-- * Replaced Power Unit Controller with Drive Unit Firmware.
-- ************************************************************************************** 
-- Revision 0.06 - 091030, CNABB/Ye-Ye Zhang
-- Configurated puc simulation ports.
-- * Set DR_TRIPX_Ns to '1'.
-- * Set GATEVOLT_17VOK to '1'.
-- * Set PWROK to '1'.
-- * Set bleederFltSD_n to '1'.
-- ************************************************************************************** 
-- Revision 0.07 - 091118, CNABB/Ye-Ye Zhang
-- Revised clk settings.
-- * Revised C_CLK_FREQ related CONSTANT and PORT.
-- ************************************************************************************** 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY duf_ip_top_tb IS

END duf_ip_top_tb;

ARCHITECTURE BEHAVIORAL OF duf_ip_top_tb IS

  COMPONENT clk_rst_tb
    GENERIC(
      C_RST_NS    : INTEGER RANGE 1 TO 1_000_000 := 2_000
      );
	 PORT(
      clk_100     : OUT STD_LOGIC;
      clk_125     : OUT STD_LOGIC;
      rst         : OUT STD_LOGIC
      );
  END COMPONENT;

  COMPONENT irq_emu_tb
    GENERIC(
      C_CLK_FREQ  : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_IRQ_NS    : INTEGER RANGE 1 TO 1_000_000 := 63_000 -- 63,000ns = 63us
      );
	 PORT(
      clk         : IN  STD_LOGIC;
	   rst         : IN  STD_LOGIC;
	   irq         : OUT STD_LOGIC
      );
  END COMPONENT;

  COMPONENT fsl_emu_tb
    PORT(
      -- FSL ports
      -- DO NOT EDIT BELOW THIS LINE ---------------------
      -- Bus protocol ports, do not add or delete. 
      FSL_Clk        : in  std_logic;
      FSL_Rst        : in  std_logic;
      FSL_S_Clk      : in  std_logic;
      FSL_S_Read     : in  std_logic;
      FSL_S_Data     : out std_logic_vector(0 to 31);
      FSL_S_Control  : out std_logic;
      FSL_S_Exists   : out std_logic;
      FSL_M_Clk      : in  std_logic;
      FSL_M_Write    : in  std_logic;
      FSL_M_Data     : in  std_logic_vector(0 to 31);
      FSL_M_Control  : in  std_logic;
      FSL_M_Full     : out std_logic
      -- DO NOT EDIT ABOVE THIS LINE ---------------------
      );
  END COMPONENT; 

  COMPONENT duf_ip_top
--    GENERIC(
--      C_CLK_FREQ               : integer range 10_000_000 to 130_000_000 := 100_000_000;
--      C_PWM_UPDATE_RATE_US     : integer range 63 to 126 := 126; -- PWM update rate in microseconds 
--      C_PWM_MIN_PULSE_WIDTH_US : integer range 3 to 6:= 5   -- PWM min pulse width time in microseconds
--      );
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
  END COMPONENT; 

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  -- set all test bench to 100MHz
  -- notice the clk/rst setting in clk_rst_tb.vhd
  CONSTANT C_CLK_FREQ           : INTEGER := 100_000_000;

  -- Clk and rst signals
  SIGNAL clk_100_i              : STD_LOGIC;
  SIGNAL clk_125_i              : STD_LOGIC;
  SIGNAL rst_i                  : STD_LOGIC;

  -- IRQ signals
  SIGNAL irq_i                  : STD_LOGIC;

  -- FSL signals
  SIGNAL FSL_S_Clk_i            : STD_LOGIC;
  SIGNAL FSL_S_Read_i           : STD_LOGIC;
  SIGNAL FSL_S_Data_i           : STD_LOGIC_VECTOR(0 TO 31);
  SIGNAL FSL_S_Control_i        : STD_LOGIC;
  SIGNAL FSL_S_Exists_i         : STD_LOGIC;
  SIGNAL FSL_M_Clk_i            : STD_LOGIC;
  SIGNAL FSL_M_Write_i          : STD_LOGIC;
  SIGNAL FSL_M_Data_i           : STD_LOGIC_VECTOR(0 TO 31);
  SIGNAL FSL_M_Control_i        : STD_LOGIC;
  SIGNAL FSL_M_Full_i           : STD_LOGIC;

BEGIN
  
  clock_reset: clk_rst_tb
	 PORT MAP(
      clk_100      => clk_100_i,
      clk_125      => clk_125_i,
      rst          => rst_i
      );

  irq_gen: irq_emu_tb
    GENERIC MAP(
      C_CLK_FREQ   => C_CLK_FREQ
      )
	 PORT MAP(
      clk          => clk_100_i,
      rst          => rst_i,
		irq          => irq_i
      );

  fsl_emulator: fsl_emu_tb
    PORT MAP(
      FSL_Clk              => clk_125_i,
      FSL_Rst              => rst_i,
      FSL_S_Clk            => FSL_S_Clk_i,
      FSL_S_Read           => FSL_S_Read_i,
      FSL_S_Data           => FSL_S_Data_i,
      FSL_S_Control        => FSL_S_Control_i,
      FSL_S_Exists         => FSL_S_Exists_i,
      FSL_M_Clk            => FSL_M_Clk_i,
      FSL_M_Write          => FSL_M_Write_i,
      FSL_M_Data           => FSL_M_Data_i,
      FSL_M_Control        => FSL_M_Control_i,
      FSL_M_Full           => FSL_M_Full_i
      );
    
  duf_ip_top_inst: duf_ip_top
--    GENERIC MAP(
--      C_CLK_FREQ           => C_CLK_FREQ
--		)
	 PORT MAP(
      -- FSL ports
	   -- DO NOT EDIT BELOW THIS LINE ---------------------
      -- Bus protocol ports, do not add or delete. 
      FSL_Clk              => clk_100_i,
      FSL_Rst              => rst_i,
      FSL_S_Clk            => FSL_S_Clk_i,
      FSL_S_Read           => FSL_S_Read_i,
      FSL_S_Data           => FSL_S_Data_i,
      FSL_S_Control        => FSL_S_Control_i,
      FSL_S_Exists         => FSL_S_Exists_i,
      FSL_M_Clk            => FSL_M_Clk_i,
      FSL_M_Write          => FSL_M_Write_i,
      FSL_M_Data           => FSL_M_Data_i,
      FSL_M_Control        => FSL_M_Control_i,
      FSL_M_Full           => FSL_M_Full_i,
      -- DO NOT EDIT ABOVE THIS LINE ---------------------
    -- IRQ ports
	 SYS_IRQ        => irq_i,
	 -- PU PWM ports
    U_pwm_top_1    => OPEN,
    U_pwm_bottom_1 => OPEN,
    V_pwm_top_1    => OPEN,
    V_pwm_bottom_1 => OPEN,
    W_pwm_top_1    => OPEN,
    W_pwm_bottom_1 => OPEN,
    U_pwm_top_2    => OPEN,
    U_pwm_bottom_2 => OPEN,
    V_pwm_top_2    => OPEN,
    V_pwm_bottom_2 => OPEN,
    W_pwm_top_2    => OPEN,
    W_pwm_bottom_2 => OPEN,
    U_pwm_top_3    => OPEN,
    U_pwm_bottom_3 => OPEN,
    V_pwm_top_3    => OPEN,
    V_pwm_bottom_3 => OPEN,
    W_pwm_top_3    => OPEN,
    W_pwm_bottom_3 => OPEN,
    U_pwm_top_4    => OPEN,
    U_pwm_bottom_4 => OPEN,
    V_pwm_top_4    => OPEN,
    V_pwm_bottom_4 => OPEN,
    W_pwm_top_4    => OPEN,
    W_pwm_bottom_4 => OPEN,
    U_pwm_top_5    => OPEN,
    U_pwm_bottom_5 => OPEN,
    V_pwm_top_5    => OPEN,
    V_pwm_bottom_5 => OPEN,
    W_pwm_top_5    => OPEN,
    W_pwm_bottom_5 => OPEN,
    U_pwm_top_6    => OPEN,
    U_pwm_bottom_6 => OPEN,
    V_pwm_top_6    => OPEN,
    V_pwm_bottom_6 => OPEN,
    W_pwm_top_6    => OPEN,
    W_pwm_bottom_6 => OPEN,
    -- PU ADC ports
    ADC_UIN1       => OPEN,
    ADC_UOUT1      => '0',
    ADC_SCLK1      => OPEN,
    ADC_CS_N1      => OPEN,
--  ADC_VIN1       => OPEN,
    ADC_VOUT1      => '0',
    ADC_UIN2       => OPEN,
    ADC_UOUT2      => '0',
    ADC_SCLK2      => OPEN,
    ADC_CS_N2      => OPEN,
--  ADC_VIN2       => OPEN,
    ADC_VOUT2      => '0',
    ADC_UIN3       => OPEN,
    ADC_UOUT3      => '0',
    ADC_SCLK3      => OPEN,
    ADC_CS_N3      => OPEN,
--  ADC_VIN3       => OPEN,
    ADC_VOUT3      => '0',
    ADC_UIN4       => OPEN,
    ADC_UOUT4      => '0',
    ADC_SCLK4      => OPEN,
    ADC_CS_N4      => OPEN,
--  ADC_VIN4       => OPEN,
    ADC_VOUT4      => '0',
    ADC_UIN5       => OPEN,
    ADC_UOUT5      => '0',
    ADC_SCLK5      => OPEN,
    ADC_CS_N5      => OPEN,
--  ADC_VIN5       => OPEN,
    ADC_VOUT5      => '0',
    ADC_UIN6       => OPEN,
    ADC_UOUT6      => '0',
    ADC_SCLK6      => OPEN,
    ADC_CS_N6      => OPEN,
--  ADC_VIN6       => OPEN,
    ADC_VOUT6      => '0',
    -- PU related ports
    DR_TRIP1_N     => '1',
    DR_TRIP2_N     => '1',
    DR_TRIP3_N     => '1',
    DR_TRIP4_N     => '1',
    DR_TRIP5_N     => '1',
    DR_TRIP6_N     => '1',
    FAULT_CLR1     => OPEN,
    FAULT_CLR2     => OPEN,
    FAULT_CLR3     => OPEN,
    FAULT_CLR4     => OPEN,
    FAULT_CLR5     => OPEN,
    FAULT_CLR6     => OPEN,
    BLEEDER_ON     => OPEN,
    RELAY_ON       => OPEN,
    GATEVOLT_17VOK => '1',
    PWROK          => '1',
    phaseTrig      => '0',
    bleederFltSD_n => '1',
    bleederFltClr  => OPEN,
    WDKick         => OPEN,
    AX_DETACH_N    => OPEN,
    -- SC related ports
    FLASHSELECT    => OPEN,
    SELECTEDFLASH  => '1',
    PROM_MISO      => '0',
    PROM_MOSI      => OPEN,
    PROM_CS_N      => OPEN,
    PROM_SCK       => OPEN,
    FLASH_MISO     => '0',
    FLASH_MOSI     => OPEN,
    FLASH_CS_N     => OPEN,
    FLASH_SCLK     => OPEN,
    RECONFIG_N     => OPEN,
    -- Test ports
    TP_111         => OPEN,
    TP_112         => '0',
    TP_113         => OPEN,
    TP_114         => OPEN,
    TP_115         => OPEN,
    TP_116         => '0',
    TP_117         => OPEN,
	 -- Legacy ports
    WDOK           => '0'
    );

END BEHAVIORAL;
