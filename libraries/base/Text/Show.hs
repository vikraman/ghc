{-# OPTIONS -fno-implicit-prelude #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Text.Show
-- Copyright   :  (c) The University of Glasgow 2001
-- License     :  BSD-style (see the file libraries/base/LICENSE)
-- 
-- Maintainer  :  libraries@haskell.org
-- Stability   :  provisional
-- Portability :  portable
--
-- The Show class and associated functions.
--
-----------------------------------------------------------------------------

module Text.Show (
   ShowS,	 	-- String -> String
   Show(
      showsPrec,	-- :: Int -> a -> ShowS
      show,		-- :: a   -> String
      showList		-- :: [a] -> ShowS 
    ),
   shows,		-- :: (Show a) => a -> ShowS
   showChar,		-- :: Char -> ShowS
   showString,		-- :: String -> ShowS
   showParen,		-- :: Bool -> ShowS -> ShowS
   showListWith,	-- :: (a -> ShowS) -> [a] -> ShowS 
 ) where

#ifdef __GLASGOW_HASKELL__
import GHC.Show
#endif   

#ifdef __GLASGOW_HASKELL__
showListWith :: (a -> ShowS) -> [a] -> ShowS 
showListWith = showList__
#else
showList__ :: (a -> ShowS) ->  [a] -> ShowS
showList__ _     []     s = "[]" ++ s
showList__ showx (x:xs) s = '[' : showx x (showl xs)
  where
    showl []     = ']' : s
    showl (y:ys) = ',' : showx y (showl ys)
#endif
