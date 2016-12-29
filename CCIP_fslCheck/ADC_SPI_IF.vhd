-- ********************************************************************
-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- ********************************************************************
-- Title:                    SPI Interface
-- File name:                spi_if.vhd
-- ********************************************************************
-- Prepared by:              Yang Gao
-- Status:                   Edited
-- Date:                     2008-06-30
-- ********************************************************************
-- Releated documents:       
--                          
-- ********************************************************************
-- Functional description:   This file is a structural description of
--                           the SPI Interface logic.
--                           The main functionality is found in the 
--                           files listed below:
--
--                           Inst.  Subunit:          Filename:
--
-- ********************************************************************
-- Revision information:
-- 2008-06-30 Björn Nyqvist: State s33 added to prolong spi_sc_n one cycle to
-- be sure that DB0 is read.
-- ********************************************************************'
-- 2008-08-18 Magnus Tysell: 
-- Median filter added for input signals from ADC. 
-- ********************************************************************

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY spi_if IS
  PORT (
    clk              : IN  STD_LOGIC;
    clk_en           : IN  STD_LOGIC;
    rst_n            : IN  STD_LOGIC;
    conversion       : IN  STD_LOGIC;
    spi_uin          : IN  STD_LOGIC;
    spi_uout         : OUT STD_LOGIC;
    spi_clk          : OUT STD_LOGIC;
    spi_cs_n         : OUT STD_LOGIC;
    spi_vin          : IN  STD_LOGIC;
    spi_vout         : OUT STD_LOGIC;
    conversion_ready : OUT STD_LOGIC;
    data_in          : IN  STD_LOGIC;
    data_out_u       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_v       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
END spi_if;

ARCHITECTURE rtl OF spi_if IS

TYPE spi_state_type IS (s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, s23, s24, s25, s26, s27, s28, s29, s30, s31, s32, s33);

SIGNAL state : spi_state_type;

SIGNAL spi_uin_i : std_logic;
SIGNAL spi_vin_i : std_logic;

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

BEGIN


  medianFilter_i0 : medianFilter
    GENERIC MAP(
      nrOfFlipFlops  => 5,
      setRstPolarity => "high"
      )
    PORT MAP(
      rst_n          => rst_n,
      clk            => clk,
      din            => spi_uin,
      dout           => spi_uin_i
      );
			
	medianFilter_i1 : medianFilter
    GENERIC MAP(
      nrOfFlipFlops  => 5,
      setRstPolarity => "high"
      )
    PORT MAP(
      rst_n          => rst_n,
      clk            => clk,
      din            => spi_vin,
      dout           => spi_vin_i
      );

  spi_sm :
  PROCESS(clk, rst_n)
  BEGIN
    IF (rst_n = '0') THEN
      state            <= s0;
      spi_cs_n         <= '1';
      spi_clk          <= '1';
      spi_uout         <= '0';
      spi_vout         <= '0';
      conversion_ready <= '0';
      data_out_u       <= (OTHERS => '0');
      data_out_v       <= (OTHERS => '0');
    ELSIF rising_edge(clk) THEN
      IF clk_en = '1' THEN
        CASE state IS
----------------------------------------------------------------------------------      
------------ Send control byte to SPI device -------------------------------------
----------------------------------------------------------------------------------

          WHEN s0 => IF conversion = '1' THEN
                       spi_cs_n       <= '0';
                       state          <= s1;
                     ELSE
                       spi_cs_n       <= '1';
                     END IF;
                     spi_clk          <= '1';
                     conversion_ready <= '0';

          WHEN s1 => spi_clk  <= '0';
                     spi_uout <= '0';   -- Control register bit 7 DONTC                            
                     spi_vout <= '0';
                     state    <= s2;

          WHEN s2 => spi_clk <= '1';
                     state   <= s3;

          WHEN s3 => spi_clk  <= '0';
                     spi_uout <= '0';   -- Control register bit 6 DONTC                
                     spi_vout <= '0';
                     state    <= s4;

          WHEN s4 => spi_clk <= '1';
                     state   <= s5;

          WHEN s5 => spi_clk  <= '0';
                     spi_uout <= '0';   -- Control register bit 5 ADD2 = '0'                                                       
                     spi_vout <= '0';
                     state    <= s6;

          WHEN s6 => spi_clk <= '1';
                     state   <= s7;

          WHEN s7 => spi_clk  <= '0';
                     spi_uout <= '0';   -- Control register bit 4 ADD1 = '0'                             
                     spi_vout <= '0';
                     state    <= s8;

          WHEN s8 => spi_clk <= '1';
                     state   <= s9;

          WHEN s9 => spi_clk  <= '0';
                     spi_uout <= data_in;  -- Control register bit 3 ADD0 = '0' or '1'  '0'= IN1 (Default) '1'= IN2                           
                     spi_vout <= data_in;
                     state    <= s10;

          WHEN s10 => spi_clk        <= '1';
                      data_out_u(11) <= spi_uin_i;  --DB11
                      data_out_v(11) <= spi_vin_i;
                      state          <= s11;

          WHEN s11 => spi_clk  <= '0';
                      spi_uout <= '0';  -- Control register bit 2 DONTC 
                      spi_vout <= '0';
                      state    <= s12;

          WHEN s12 => spi_clk        <= '1';
                      data_out_u(10) <= spi_uin_i;  --DB10
                      data_out_v(10) <= spi_vin_i;
                      state          <= s13;

          WHEN s13 => spi_clk  <= '0';
                      spi_uout <= '0';  -- Control register bit 1 DONTC                             
                      spi_vout <= '0';
                      state    <= s14;

          WHEN s14 => spi_clk       <= '1';
                      data_out_u(9) <= spi_uin_i;  --DB9
                      data_out_v(9) <= spi_vin_i;
                      state         <= s15;

          WHEN s15 => spi_clk  <= '0';
                      spi_uout <= '0';  -- Control register bit 0 DONTC
                      spi_vout <= '0';
                      state    <= s16;

          WHEN s16 => spi_clk       <= '1';
                      data_out_u(8) <= spi_uin_i;  --DB8
                      data_out_v(8) <= spi_vin_i;
                      state         <= s17;

          WHEN s17 => spi_clk <= '0';
                      state   <= s18;

          WHEN s18 => spi_clk       <= '1';
                      data_out_u(7) <= spi_uin_i;  --DB7
                      data_out_v(7) <= spi_vin_i;
                      state         <= s19;

          WHEN s19 => spi_clk <= '0';
                      state   <= s20;

          WHEN s20 => spi_clk       <= '1';
                      data_out_u(6) <= spi_uin_i;  --DB6
                      data_out_v(6) <= spi_vin_i;
                      state         <= s21;

          WHEN s21 => spi_clk <= '0';
                      state   <= s22;

          WHEN s22 => spi_clk       <= '1';
                      data_out_u(5) <= spi_uin_i;  --DB5
                      data_out_v(5) <= spi_vin_i;
                      state         <= s23;

          WHEN s23 => spi_clk <= '0';
                      state   <= s24;

          WHEN s24 => spi_clk       <= '1';
                      data_out_u(4) <= spi_uin_i;  --DB4
                      data_out_v(4) <= spi_vin_i;
                      state         <= s25;

          WHEN s25 => spi_clk <= '0';
                      state   <= s26;

          WHEN s26 => spi_clk       <= '1';
                      data_out_u(3) <= spi_uin_i;  --DB3
                      data_out_v(3) <= spi_vin_i;
                      state         <= s27;

          WHEN s27 => spi_clk <= '0';
                      state   <= s28;

          WHEN s28 => spi_clk       <= '1';
                      data_out_u(2) <= spi_uin_i;  --DB2
                      data_out_v(2) <= spi_vin_i;
                      state         <= s29;

          WHEN s29 => spi_clk <= '0';
                      state   <= s30;

          WHEN s30 => spi_clk       <= '1';
                      data_out_u(1) <= spi_uin_i;  --DB1
                      data_out_v(1) <= spi_vin_i;
                      state         <= s31;

          WHEN s31 => spi_clk <= '0';
                      state   <= s32;

          WHEN s32 => spi_clk          <= '1';
                      data_out_u(0)    <= spi_uin_i;  --DB0
                      data_out_v(0)    <= spi_vin_i;
                      --conversion_ready <= '1';
                      --spi_cs_n <= '1';
                      --state    <= s0;
                      state    <= s33;
          WHEN s33 => spi_cs_n <= '1';
                      conversion_ready <= '1';
                      state    <=  s0;
        END CASE;
      END IF;
    END IF;
  END PROCESS spi_sm;

END rtl;
