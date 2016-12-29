-------------------------------------------------------------------------------
-- $Id: async_fifo.vhd,v 1.1 2007/04/24 12:40:27 rolandp Exp $
-------------------------------------------------------------------------------
-- Async_FIFO.vhd - Entity and architecture
--
--  ***************************************************************************
--  **  Copyright(C) 2003 by Xilinx, Inc. All rights reserved.               **
--  **                                                                       **
--  **  This text contains proprietary, confidential                         **
--  **  information of Xilinx, Inc. , is distributed by                      **
--  **  under license from Xilinx, Inc., and may be used,                    **
--  **  copied and/or disclosed only pursuant to the terms                   **
--  **  of a valid license agreement with Xilinx, Inc.                       **
--  **                                                                       **
--  **  Unmodified source code is guaranteed to place and route,             **
--  **  function and run at speed according to the datasheet                 **
--  **  specification. Source code is provided "as-is", with no              **
--  **  obligation on the part of Xilinx to provide support.                 **
--  **                                                                       **
--  **  Xilinx Hotline support of source code IP shall only include          **
--  **  standard level Xilinx Hotline support, and will only address         **
--  **  issues and questions related to the standard released Netlist        **
--  **  version of the core (and thus indirectly, the original core source). **
--  **                                                                       **
--  **  The Xilinx Support Hotline does not have access to source            **
--  **  code and therefore cannot answer specific questions related          **
--  **  to source HDL. The Xilinx Support Hotline will only be able          **
--  **  to confirm the problem in the Netlist version of the core.           **
--  **                                                                       **
--  **  This copyright and support notice must be retained as part           **
--  **  of this text at all times.                                           **
--  ***************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        Async_FIFO.vhd
--
-- Description:     
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--              Async_FIFO.vhd
--
-------------------------------------------------------------------------------
-- Author:          goran
-- Revision:        $Revision: 1.1 $
-- Date:            $Date: 2007/04/24 12:40:27 $
--
-- History:
--   goran  2003-10-27    First Version
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use IEEE.numeric_std.all;

entity Async_FIFO is
  generic (
    WordSize : Integer := 8;
    MemSize  : Integer := 16;
    Protect  : Boolean := False
    );
  port (
    Reset   : in  Std_Logic;
    -- Clock region WrClk
    WrClk   : in  Std_Logic;
    WE      : in  Std_Logic;
    DataIn  : in  Std_Logic_Vector(WordSize-1 downto 0);
    Full    : out Std_Logic;
    -- Clock region RdClk
    RdClk   : in  Std_Logic;
    RD      : in  Std_Logic;
    DataOut : out Std_Logic_Vector(WordSize-1 downto 0);
    Exists  : out Std_Logic
    );
end Async_FIFO;

architecture VHDL_RTL of ASync_FIFO is

  -----------------------------------------------------------------------------
  -- A function which tries to calculate the best Mem_Size and by that the best
  -- counting scheme
  -----------------------------------------------------------------------------
  function Calculate_Right_Mem_Size (Mem_Size : in Natural) return Integer is
  begin  -- Calculate_Right_Mem_Size
    case Mem_Size is
      when 0 to 3 =>
        assert false report "To small FIFO" severity failure;
        return 0;
      when 4 to 16 => return 16;
      when 17 to 32 => return 32;
      when 33 to 48 =>
        -- Check if to use up/down counter instead of a true 6-bit grey counter
        -- It seems that the up/down counter takes 9 more CLBs than a ordinary
        -- grey counter so if the width is greater than 9 the up/down counter
        -- will save area
        if WordSize > 8 then
          return 48;
        else
          return 64;
        end if;
      when 49 to 64 => return 64;
      when 65 to 128 =>
        -- Do not yet need to check if to use the up/down counting scheme since
        -- there is not true 7-bit counter implemented yet
        return ((MemSize+15)/16)*16;
      when others =>
        assert false
          report "Unsupported FIFO Depth (Not yet implemented)"
          severity failure;
        return 0;
    end case;
  end Calculate_Right_Mem_Size;

  -----------------------------------------------------------------------------
  -- Create a resolved Boolean type (rboolean)
  -----------------------------------------------------------------------------

  -- Create a Boolean array type
  type boolean_array is array (natural range <>) of boolean;

  -- Function for resolved boolean
  -- If any boolean in the array is false, then the result is false
  function resolve_boolean( values: in boolean_array ) return boolean is
    variable result: boolean := TRUE;
  begin
    if (values'length = 1) then
       result := values(values'low);
    else
       for index in values'range loop
          if values(index) = FALSE then
             result := FALSE;
          end if;
       end loop;
    end if;
    return result;
  end function resolve_boolean;

  subtype rboolean is resolve_boolean boolean;

  
  -- Convert the FIFO memsize to memsizes in steps of 16
  constant True_Mem_Size : Integer := Calculate_Right_Mem_Size(MemSize);

--   component Gen_DpRAM
--     generic (
--       Use_Muxes : Boolean := False;
--       Mem_Size  : Integer := 36;
--       Addr_Size : Integer := 6;
--       Data_Size : Integer := 16
--       );
--     port (
--       Reset    : in  Std_Logic;
--       -- Read/Write port 1
--       Addr1    : in  Std_Logic_Vector(Addr_Size-1 downto 0);
--       WrClk    : in  Std_Logic;
--       WE       : in  Std_Logic;
--       DataIn   : in  Std_Logic_Vector(Data_Size-1 downto 0);
--       DataOut1 : out Std_Logic_Vector(Data_Size-1 downto 0);
--       -- Read port 2
--       Addr2    : in  Std_Logic_Vector(Addr_Size-1 downto 0);
--       DataOut2 : out Std_Logic_Vector(Data_Size-1 downto 0)
--       );
--   end component;    

  ----------------------------------------------------------------------
  -- Returns the vector size needed to represent the X
  -- The result is > 0
  ----------------------------------------------------------------------
  function Vec_Size( X : in Natural) return Natural is
    variable I : Natural := 1;
  begin
    while (2**I) < X loop
      I := I + 1;
    end loop;
    return I;
  end function Vec_Size;

  -- Declare the types and constant counting schemes
  subtype Count_Word is Std_Logic_Vector(3 downto 0);
  type Count_Array_Type is array (integer range <>) of Count_Word;

  -- Even if there is four bits for the Cnt8, the fourth bit will never be used
  constant Cnt8  : Count_Array_Type(0 to  7) := ( "0000","0001","0011","0010",
                                                  "0110","0111","0101","0100");
  constant Cnt10 : Count_Array_Type(0 to  9) := ( "0000","1000","1001","0001",
                                                  "0011","0010","0110","0111",
                                                  "0101","0100" );
  constant Cnt12 : Count_Array_Type(0 to 11) := ( "0000","1000","1001","1011",
                                                  "1010","0010","0011","0001",
                                                  "0101","0111","0110","0100" );
  constant Cnt14 : Count_Array_Type(0 to 13) := ( "0000","1000","1100","1101",
                                                  "1001","1011","1010","0010",
                                                  "0011","0001","0101","0111",
                                                  "0110","0100");
  constant Cnt16 : Count_Array_Type(0 to 15) := ( "0000","0001","0011","0010",
                                                  "0110","0100","0101","0111",
                                                  "1111","1110","1100","1101",
                                                  "1001","1011","1010","1000");

  -----------------------------------------------------------------------------
  -- A function that do all the boolean equations for a counting scheme
  -- given as a parameter
  -- The synthesis tool will unroll the loops and then do the boolean equation
  -- minimization (hopefully the optimimal).
  -- At present it only handles counting scheme with 4 bits due to the
  -- Count_Array_Type definition
  -----------------------------------------------------------------------------
  function Gen_Counter(Count_Scheme : in Count_Array_Type;
                       Up           : in Boolean;
                       Count        : in Std_Logic_Vector)
          return Std_Logic_Vector is
    variable Temp   : Std_Logic;
    variable L      : Integer range Count_Scheme'Range;
    variable Q      : Std_Logic_Vector(Count'Length-1 downto 0);
    variable Q_Temp : Std_Logic_Vector(Count'Length-1 downto 0);
  begin  -- Gen_Counter
    Q := Count;
    for G in Q'Range loop
      Q_Temp(G) := '0';
      for I in Count_Scheme'range loop
        if Count_Scheme(I)(G) = '1' then
          if Up then 
            L := I - 1;
          else
            if I /= Count_Scheme'High then
              L := I + 1;
            else
              L := Count_Scheme'Low;
            end if;
          end if;
          Temp := '1';
          for J in Q'Range loop
            if Count_Scheme(L)(J) = '1' then
              Temp := Temp and Q(J);
            else
              Temp := Temp and  not Q(J);                  
            end if;
          end loop;
          Q_Temp(G) := Q_Temp(G) or Temp;
        end if;
      end loop;  -- I
    end loop;  -- G
    return Q_Temp;
  end Gen_Counter;

  -----------------------------------------------------------------------------
  -- Implements the improved 32-depth FIFO counting scheme from the XAPP051
  -----------------------------------------------------------------------------
  function XAPP_Count_32 (Q : in Std_Logic_Vector(4 downto 0))
           return Std_Logic_Vector is    
    variable Res : Std_Logic_Vector(4 downto 0);
    variable A   : Std_Logic;
  begin  -- XAPP_Count_32
    -- Do Peter Alfke improvement on XAPP 051
    A := (Q(1) xnor Q(2)) and (Q(0) xor (Q(4) xor Q(3)));
    Res(0) := (Q(1) and not A) or (Q(0) and A);
    Res(1) := (not(Q(0)) and not A) or (Q(1) and A);
    Res(2) := ( (Q(4) xnor Q(3)) and A) or (Q(2) and not A);
    Res(3) := ( ( (Q(2) and not Q(4)) or (not(Q(2) and Q(3)))) and A) or
              (Q(3) and not A);
    Res(4) := ( ( (Q(2) and Q(4)) or (not(Q(2)) and Q(3))) and A) or
              (Q(4) and not A);
    return Res;
  end XAPP_Count_32;

  -----------------------------------------------------------------------------
  -- Implements the improved 64-depth FIFO counting scheme from the XAPP051
  -----------------------------------------------------------------------------
--  function XAPP_Count_64 (Q : in Std_Logic_Vector(5 downto 0))
--           return Std_Logic_Vector is
--    variable Res : Std_Logic_Vector(5 downto 0);
--    variable A   : Std_Logic;
--  begin  -- XAPP_Count_64
--    -- Do Peter Alfke improvement on XAPP 051
--    A := (Q(1) xor Q(4)) and (Q(0) xnor Q(3)) and (Q(2) xnor Q(5));
--    Res(0) := (not(Q(3) xor Q(2))) xor (Q(2) and Q(1) and Q(0));
--    Res(1) := Q(0);
--    Res(2) := Q(1);
--    Res(3) := Q(2);
--    A := Q(3) and not(Q(2)) and not(Q(1)) and not(Q(0));    
--    Res(4) := (A and not(Q(4))) or (not(A) and Q(5));
--    Res(5) := (A and Q(5)) or (not(A) and Q(4));
--    return Res;
--  end XAPP_Count_64;
  function XAPP_Count_64 (Q : in Std_Logic_Vector(5 downto 0))
           return Std_Logic_Vector is
    variable Res : Std_Logic_Vector(5 downto 0);
    variable A   : Std_Logic;
  begin  -- XAPP_Count_64
    -- Do Peter Alfke improvement on XAPP 051
    A := (Q(1) xor Q(4)) and (Q(0) xnor Q(3)) and (Q(2) xnor Q(5));
    Res(0) := ( (Q(1) xnor Q(2)) and not A) or (Q(0) and A);
    Res(1) := ( ( (not(Q(0)) and Q(2)) or (Q(0) and Q(1))) and not A) or
              (Q(1) and A);
    Res(2) := ( ( (Q(0) and not Q(1)) or (not(Q(0) and Q(2)))) and not A) or
              (Q(2) and A);
    Res(3) := ( (Q(4) xnor Q(5)) and A) or (Q(3) and not A);
    Res(4) := ( ( (not(Q(3) and Q(5))) or (Q(3) and Q(4))) and A ) or
              (Q(4) and not A);
    Res(5) := ( ( (Q(3) and not Q(4)) or (not(Q(3)) and Q(5))) and A ) or
              (Q(5) and not A);
    return Res;
  end XAPP_Count_64;
  
  ----------------------------------------------------------------------
  -- Generate the Address counter for FIFO handling
  -- generates different counters depending of the counter size
  ----------------------------------------------------------------------
  Procedure FIFO_Count( Count : inout Std_Logic_Vector;
                        Incr  : in    Boolean;
                        Up    : inout Boolean;
                        Change : inout Boolean) is
    variable Cnt : Std_Logic_Vector(Count'Left-Count'Right downto 0) := Count;
    variable Res : Std_Logic_Vector(Count'Left-Count'Right downto 0) := Count;
  begin
    if True_Mem_Size = 16 then
      if Incr then
        Res := Gen_Counter(Cnt16,True,Cnt);
      end if;
    elsif True_Mem_Size = 32 then
      -- For some reasons the XAPP_Count_64 doesn't work correctly
      -- Implement the 32 bit counter with a 2 bit counter and 8 bit counter
--      if Incr then
--        Res := XAPP_Count_32(Cnt);
--      end if;
      if Incr then
        if not Change and
          (( (Cnt(2 downto 0) = "100") and Up) or
           ( (Cnt(2 downto 0) = "000") and not Up)) then
          Res(4)          := Cnt(3);
          Res(3)          := not Cnt(4);
          Res(2 downto 0) := Cnt(2 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(4 downto 3) := Cnt(4 downto 3);
          Res(2 downto 0) := Gen_Counter(Cnt8,Up,Cnt(2 downto 0));
        end if;
      end if;
    elsif True_Mem_Size = 48 then
      -- Do a 2-bit grey counter + a grey counter which counts between 0 to 11
      if Incr then
        if not Change and
          (( (Cnt(3 downto 0) = Cnt12(Cnt12'High)) and Up) or
           ( (Cnt(3 downto 0) = Cnt12(Cnt12'Low)) and not Up)) then
          Res(5)          := Cnt(4);
          Res(4)          := not Cnt(5);
          Res(3 downto 0) := Cnt(3 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(5 downto 4) := Cnt(5 downto 4);
          Res(3 downto 0) := Gen_Counter(Cnt12,Up,Cnt(3 downto 0));
        end if;
      end if;
    elsif True_Mem_Size = 64 then
      -- For some reasons the XAPP_Count_64 doesn't work correctly
      -- Implement the 64 bit counter with a 2 bit counter and 16 bit counter
--      if Incr then
--        Res := XAPP_Count_64(Cnt);
--      end if;
      if Incr then
        if not Change and
          (( (Cnt(3 downto 0) = Cnt16(Cnt16'High)) and Up) or
           ( (Cnt(3 downto 0) = Cnt16(Cnt16'Low)) and not Up)) then
          Res(5)          := Cnt(4);
          Res(4)          := not Cnt(5);
          Res(3 downto 0) := Cnt(3 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(5 downto 4) := Cnt(5 downto 4);
          Res(3 downto 0) := Gen_Counter(Cnt16,Up,Cnt(3 downto 0));
        end if;
      end if;
    elsif True_Mem_Size = 80 then
      -- Do a 3-bit grey counter + a grey counter which counts between 0 to 9
      if Incr then
        if not Change and
          (( (Cnt(3 downto 0) = Cnt10(Cnt10'High)) and Up) or
           ( (Cnt(3 downto 0) = Cnt10(Cnt10'Low)) and not Up)) then
          Res(6 downto 4) := Gen_Counter(Cnt8,True,Cnt(6 downto 4));
          Res(3 downto 0) := Cnt(3 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(6 downto 4) := Cnt(6 downto 4);
          Res(3 downto 0) := Gen_Counter(Cnt10,Up,Cnt(3 downto 0));
        end if;
      end if;
    elsif True_Mem_Size = 96 then
      -- Do a 3-bit grey counter + a grey counter which counts between 0 to 11
      if Incr then
        if not Change and
          (( (Cnt(3 downto 0) = Cnt12(Cnt12'High)) and Up) or
           ( (Cnt(3 downto 0) = Cnt12(Cnt12'Low)) and not Up)) then
          Res(6 downto 4) := Gen_Counter(Cnt8,True,Cnt(6 downto 4));
          Res(3 downto 0) := Cnt(3 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(6 downto 4) := Cnt(6 downto 4);
          Res(3 downto 0) := Gen_Counter(Cnt12,Up,Cnt(3 downto 0));
        end if;
      end if;
    elsif True_Mem_Size = 112 then
      -- Do a 3-bit grey counter + a grey counter which counts between 0 to 13
      if Incr then
        if not Change and
          (( (Cnt(3 downto 0) = Cnt14(Cnt14'High)) and Up) or
           ( (Cnt(3 downto 0) = Cnt14(Cnt14'Low)) and not Up)) then
          Res(6 downto 4) := Gen_Counter(Cnt8,True,Cnt(6 downto 4));
          Res(3 downto 0) := Cnt(3 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(6 downto 4) := Cnt(6 downto 4);
          Res(3 downto 0) := Gen_Counter(Cnt14,Up,Cnt(3 downto 0));
        end if;
      end if;
    elsif True_Mem_Size = 128 then
      -- Do a 3-bit grey counter + a 4-bit grey counter
      if Incr then
        if not Change and
          (( (Cnt(3 downto 0) = Cnt16(Cnt16'High)) and Up) or
           ( (Cnt(3 downto 0) = Cnt16(Cnt16'Low)) and not Up)) then
          Res(6 downto 4) := Gen_Counter(Cnt8,True,Cnt(6 downto 4));
          Res(3 downto 0) := Cnt(3 downto 0);
          Up              := not Up;
          Change          := True;
        else
          Change          := False;
          Res(6 downto 4) := Cnt(6 downto 4);
          Res(3 downto 0) := Gen_Counter(Cnt16,Up,Cnt(3 downto 0));
        end if;
      end if;      
    else
      assert false
        report "To BIG FIFO (not yet supported)"
        severity failure;
    end if;
    Count := Res;
  end FIFO_Count;

  Procedure FIFO_Counter( signal Count : inout Std_Logic_Vector;
                        Incr  : in    Boolean;
                        Up    : inout Boolean;
                        Change : inout Boolean) is 
    variable Res : Std_Logic_Vector(Count'Left-Count'Right downto 0) := Count;   
  begin 
     FIFO_Count(Res,Incr,Up,Change);   
     Count <= Res;
  end FIFO_Counter;

  constant Log2_Mem_Size : Integer := Vec_Size(True_Mem_Size);
  
  -- The read and write pointers
  subtype Pointer_Type is Std_Logic_Vector(Log2_Mem_Size-1 downto 0);
  signal Write_Ptr       : Pointer_Type;
  signal Read_Ptr        : Pointer_Type;
  signal Write_Addr      : Pointer_Type;
  signal Read_Addr       : Pointer_Type;

  signal DataOut1 : Std_Logic_Vector(WordSize-1 downto 0); -- NOT USED

  signal Dir_Latched : Boolean;
  signal Direction   : Boolean;
  signal Equal       : Boolean;
  signal Full_I      : Boolean;
  signal Empty_I     : Boolean;
  signal Full_Out    : Boolean;
  signal Empty_Out   : Boolean;

  signal Read  : rboolean;
  signal Write : rboolean;

  -----------------------------------------------------------------------------
  -- Implement the RAM with pure RTL
  -----------------------------------------------------------------------------
  type RAM_TYPE is array (natural range 0 to MemSize-1) of std_logic_vector(WordSize-1 downto 0);
  signal Memory : RAM_TYPE := (others => (others => '0'));
  
begin

  -----------------------------------------------------------------------------
  -- Change the Read and Write pointer to get the FIFO addresses
  -- This will get the four lowest bits from the Read/Write pointers to be the
  -- higest bits in FIFO addresses. This assures that when the FIFO depth is
  -- not a power of 2, that the FIFO addresses is within the FIFO depth range
  -----------------------------------------------------------------------------
  Do_FIFO_Addr : process (Write_Ptr, Read_Ptr)
  begin  -- process Do_FIFO_Addr
    Write_Addr(Write_Addr'High downto Write_Addr'High-3) <=
      Write_Ptr(3 downto 0);
    if Write_Ptr'Length > 4 then
      Write_Addr(Write_Addr'High-4 downto Write_Addr'Low) <=
        Write_Ptr(Write_Ptr'High downto 4);
    end if;
    Read_Addr(Read_Addr'High downto Read_Addr'High-3) <=
      Read_Ptr(3 downto 0);
    if Read_Ptr'Length > 4 then
      Read_Addr(Read_Addr'High-4 downto Read_Addr'Low) <=
        Read_Ptr(Read_Ptr'High downto 4);
    end if;
  end process Do_FIFO_Addr;
  
  ----------------------------------------------------------------------
  -- Instansiate the Dual Port memory
  ----------------------------------------------------------------------
  Write_To_Memory: process (WrClk) is
  begin  -- process Write_To_Memory
    if WrClk'event and WrClk = '1' then     -- rising clock edge
      if WE = '1' then
        Memory(to_integer(unsigned(Write_Addr))) <= DataIn;
      end if;
    end if;
  end process Write_To_Memory;

  DataOut1 <= Memory(to_integer(unsigned(Write_Addr)));
  DataOut  <= Memory(to_integer(unsigned(Read_Addr)));
  
--  FIFO_MEM :  Gen_DpRAM 
--    generic map(
--      Use_Muxes => true,
--      Mem_Size  => MemSize,
--      Addr_Size => Log2_Mem_Size,
--      Data_Size => WordSize
--      )
--    port map (
--      Reset    => Reset,
--      Addr1    => Write_Addr,
--      WrClk    => WrClk,
--      WE       => WE,
--      DataIn   => DataIn,
--      DataOut1 => DataOut1,
--      Addr2    => Read_Addr,
--      DataOut2 => DataOut
--      );

  Protect_FIFO : if Protect generate
    Read  <= (Rd = '1') and not Empty_Out;
    Write <= (We = '1') and not Full_Out;
  end generate Protect_FIFO;

  Non_Protect_FIFO : if not Protect generate
    Read  <= (Rd = '1');
    Write <= (We = '1');
  end generate Non_Protect_FIFO;
  ----------------------------------------------------------------------
  -- Read Pointer
  ----------------------------------------------------------------------
  Read_Ptr_Counter : process(Reset,RdClk)
    variable Up     : Boolean;
    variable Change : Boolean;
  begin
    if (Reset = '1') then
      Read_Ptr <= (others => '0');
      Up       := True;
      Change   := False;
    elsif RdClk'Event and RdClk = '1' then
      FIFO_Counter(Read_Ptr,Read,Up,Change);
    end if;
  end process Read_Ptr_Counter;
  
  ----------------------------------------------------------------------
  -- Write Pointer
  ----------------------------------------------------------------------
  Write_Ptr_Counter : process(Reset,WrClk)
    variable Up     : Boolean;
    variable Change : Boolean;
  begin
    if (Reset = '1') then
      Write_Ptr <= (others => '0');
      Up        := True;
      Change   := False;
    elsif WrClk'Event and WrClk = '1' then
      FIFO_Counter(Write_Ptr,Write,Up,Change);
    end if;
  end process Write_Ptr_Counter;
  
  ----------------------------------------------------------------------
  -- Flag handling
  ----------------------------------------------------------------------

  -------------------------------------------------------------------------
  -- Dir_Latched is false after reset and then true after the first write
  ---------------------------------------------------------------------------
  Direction_Latch : process(Reset,WE,WrClk)
  begin
    if (Reset = '1') then
      Dir_Latched <= False;
    elsif WrClk'Event and WrClk = '1' then
      Dir_Latched <= Dir_Latched or (WE = '1');
    end if;
  end process Direction_Latch;

  -----------------------------------------------------------------------------
  -- Trying to see if the read pointer is catching up the write pointer or
  -- vice verse
  -- The top two bits of the pointers always counts as follows
  -- 00
  -- 01
  -- 11
  -- 10
  -- 00
  -- ..
  -- So if read pointer is one step behind the write pointer => Reset = True
  -- And if write pointer is one step behind the read pointer => Set = True
  -----------------------------------------------------------------------------
  Direction_Proc : process(Read_Ptr,Write_Ptr,Dir_Latched,Direction)
    variable Set   : Boolean;
    variable Reset : Boolean;
    variable Read  : Std_Logic_Vector(1 downto 0);
    variable Write : Std_Logic_Vector(1 downto 0);
  begin 
   Read  := Read_Ptr(Read_Ptr'Left) & Read_Ptr(Read_Ptr'Left-1);
   Write := Write_Ptr(Write_Ptr'Left) & Write_Ptr(Write_Ptr'Left-1);
   if (Read = "00" and Write = "01") or 
      (Read = "01" and Write = "11") or 
      (Read = "11" and Write = "10") or 
      (Read = "10" and Write = "00") then 
     Reset := True;
   else
     Reset := False;
   end if;
   if (Write = "00" and Read = "01") or 
      (Write = "01" and Read = "11") or
      (Write = "11" and Read = "10") or
      (Write = "10" and Read = "00") then
     Set := True;
   else
     Set := False;
   end if;
   Direction <= not ((not Dir_Latched) or Reset or not(Set or Direction));
  end process Direction_Proc;

  Equal   <= (Read_Ptr = Write_Ptr);
  Full_I  <= Equal and Direction;
  Empty_I <= Equal and not Direction;
             
  -- Allow Empty to go active directly since the change is due to a read
  -- which means that the Empty_I is synchronized with RdClk.
  -- But is only allow to go inactive when RdClk is High since the transaction
  -- is due to a Write and Empty_I is NOT synchronized with RdClk.
  -- By this way the Empty is not changed state just before rising edge of RdClk
  Empty_DFF : process(Empty_I,RdClk)
  begin
    if Empty_I then
      Empty_Out <= True;
    elsif RdClk'Event and RdClk = '1' then
      Empty_Out <= Empty_I;
    end if;
  end process Empty_DFF;

  Exists <= '0' when Empty_Out else '1';

  -- See above but for Full and WrClk
  Full_DFF : process(Full_I,WrClk)
  begin
    if Full_I then
      Full_Out <= True;
    elsif WrClk'Event and WrClk = '1' then
      Full_Out <= Full_I;
    end if;
  end process Full_DFF;

  Full <= '1' when Full_Out else '0';
  
end VHDL_RTL;


