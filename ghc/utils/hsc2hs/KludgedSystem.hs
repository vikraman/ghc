{-# OPTIONS -cpp -fglasgow-exts #-}
-----------------------------------------------------------------------------
-- $Id: KludgedSystem.hs,v 1.6 2001/04/02 16:10:05 rrt Exp $

-- system that works feasibly under Windows (i.e. passes the command line to sh,
-- because system() under Windows doesn't look at SHELL, and always uses CMD.EXE)

module KludgedSystem (system, defaultCompiler, progNameSuffix) where

#include "../../includes/config.h"

#ifndef mingw32_TARGET_OS

import System (system)

defaultCompiler :: String
defaultCompiler = "gcc"
progNameSuffix = ""

#else

import qualified System
import System    (ExitCode)
import IO        (bracket_)
import Directory (removeFile)
import Config

system :: String -> IO ExitCode
system cmd = do
    pid <- getProcessID
    let tmp = cDEFAULT_TMPDIR++"/sh"++show pid
    writeFile tmp (cmd++"\n")
    bracket_ (return tmp) removeFile $ System.system ("sh - "++tmp)

foreign import "_getpid" unsafe getProcessID :: IO Int

defaultCompiler :: String
defaultCompiler = "gcc -mno-cygwin -mwin32"
progNameSuffix = ".exe"

#endif /* mingw32_TARGET_OS */
