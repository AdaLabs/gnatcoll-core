with System.Assertions; use System.Assertions;
with Ada.Exceptions; use Ada.Exceptions;
with GNATCOLL.Opt_Parse; use GNATCOLL.Opt_Parse;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Test_Assert;

function Test return Integer is
   package A renames Test_Assert;
begin
   declare
      pragma Warnings (Off);
      --  We ignore warnings, because GNAT is actually smart enough to catch
      --  the assert failure at compile time and emit a warning for it

      package Args is
         Parser : Argument_Parser :=
            Create_Argument_Parser (Help => "Test program");

         package Charset_Option1 is new Parse_Option
           (Parser      => Parser,
            Arg_Type    => Unbounded_String,
            Name        => "Charset",
            Help        =>
               "What charset to use when parsing files. "
               & "Default is ""latin-1""",
            Default_Val => To_Unbounded_String ("latin-1"));

      end Args;

   begin
      if Args.Parser.Parse ((1 .. 0 => <>)) then
         A.Assert (False, "Should not be reached");
      end if;
   end;

   return A.Report;
exception
   when E : Assert_Failure =>
      A.Assert
        (Exception_Message (E)
         = "You should have either a long or a short flag",
         "Wrong exception msg");
      return A.Report;
end Test;
