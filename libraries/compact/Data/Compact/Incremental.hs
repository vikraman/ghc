{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE UnboxedTuples #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Compact
-- Copyright   :  (c) The University of Glasgow 2001-2009
--                (c) Giovanni Campagna <gcampagn@cs.stanford.edu> 2014
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  libraries@haskell.org
-- Stability   :  unstable
-- Portability :  non-portable (GHC Extensions)
--
-- This module provides a data structure, called a Compact, for holding
-- a set of fully evaluated Haskell values in a consecutive block of
-- memory.
--
-- As the data fully evaluated and pure (thus immutable), it maintains
-- the invariant that no memory reference exist from objects inside the
-- Compact to objects outside, thus allowing very fast garbage collection
-- (at the expense of increased memory usage, because the entire set of
-- object is kept alive if any object is alive).
--
-- This is similar to Data.Compact, but it supports incremental evaluation
-- into Compact structures.
--
-- /Since: 1.0.0/
module Data.Compact.Incremental (
  Compact,
  compactGetRoot,
  compactResize,

  compactNew,
  compactAppendOne,
  compactAppendRecursively,
  compactAppendEvaled,

  Compactable,
  compact,
  defaultCompactNFData,

  SerializedCompact(..),
  withCompactPtrs,
  compactImport,
  compactImportByteStrings,
  ) where

-- Write down all GHC.Prim deps explicitly to keep them at minimum
import GHC.Prim (compactNew#,
                 compactAppendOne#,
                 compactContains#,
                 compactContainsAny#,
                 anyToAddr#,
                 )
-- We need to import Word from GHC.Types to see the representation
-- and to able to access the Word# to pass down the primops
import GHC.Types (IO(..), Word(..), isTrue#)

import Data.Compact.Imp(Compact(..),
                        compactGetRoot,
                        compactGetBuffer,
                        compactResize,
                        compactAppendEvaledInternal,
                        SerializedCompact(..),
                        withCompactPtrs,
                        compactImport,
                        compactImportByteStrings)

import Control.DeepSeq (NFData, force)

compactNew :: Compactable a => Word -> a -> IO (Compact a)
compactNew (W# size) val = do
  -- cheap trick: () is a constant and so Compact () is the empty compact
  -- and we don't need to append or adjust the address
  unitStr <- IO (\s -> case compactNew# size s of
                    (# s', buffer #) -> case anyToAddr# () of
                      (# rootAddr #) -> (# s', Compact buffer rootAddr #) )
  compactAppendRecursively unitStr val

compactAppendEvaled :: Compact b -> a -> IO (Compact a)
compactAppendEvaled str !root =
  let buffer = compactGetBuffer str
  in
   IO (\s -> compactAppendEvaledInternal buffer root 0# s)

class Compactable a where
  compact :: Compact b -> a -> IO (Compact a)

compactAppendRecursively :: Compactable a => Compact b -> a -> IO (Compact a)
compactAppendRecursively str@(Compact buffer _) !val = do
  if isTrue# (compactContains# buffer val) then
    case anyToAddr# val of
      (# rootAddr #) -> return $ Compact buffer rootAddr
    else if isTrue# (compactContainsAny# val) then
           compactAppendEvaled str val
         else
           compact str val

compactAppendOne :: Compact b -> a -> IO (Compact a)
compactAppendOne (Compact buffer _) !val =
  IO (\s -> case compactAppendOne# buffer val s of
         (# s', rootAddr #) -> (# s', Compact buffer rootAddr #) )

-- | 'defaultCompactNFData': a default implementation for compact suitable
-- | for NFData instances
defaultCompactNFData :: NFData a => Compact b -> a -> IO (Compact a)
defaultCompactNFData str v = compactAppendEvaled str (force v)

appendRec :: Compactable a => Compact b -> a -> IO a
appendRec str val = do
  !str' <- compactAppendRecursively str val
  return $ compactGetRoot str'

instance Compactable a => Compactable [a] where
  compact str [] = compactAppendOne str []
  compact str (x:xs) = do
    !xs' <- appendRec str xs
    !x' <- appendRec str x
    compactAppendOne str (x':xs')

instance Compactable () where
  compact str val = compactAppendOne str val

instance (Compactable a, Compactable b) => Compactable (a,b) where
  compact str (l, r) = do
    !l' <- appendRec str l
    !r' <- appendRec str r
    compactAppendOne str (l', r')

instance (Compactable a, Compactable b, Compactable c) =>
         Compactable (a,b,c) where
  compact str (v1, v2, v3) = do
    !v1' <- appendRec str v1
    !v2' <- appendRec str v2
    !v3' <- appendRec str v3
    compactAppendOne str (v1',v2',v3')

instance (Compactable a, Compactable b, Compactable c, Compactable d) =>
         Compactable (a,b,c,d) where
  compact str (v1, v2, v3, v4) = do
    !v1' <- appendRec str v1
    !v2' <- appendRec str v2
    !v3' <- appendRec str v3
    !v4' <- appendRec str v4
    compactAppendOne str (v1',v2',v3',v4')

instance (Compactable a, Compactable b, Compactable c, Compactable d,
          Compactable e) => Compactable (a,b,c,d,e) where
  compact str (v1, v2, v3, v4, v5) = do
    !v1' <- appendRec str v1
    !v2' <- appendRec str v2
    !v3' <- appendRec str v3
    !v4' <- appendRec str v4
    !v5' <- appendRec str v5
    compactAppendOne str (v1',v2',v3',v4',v5')

instance Compactable a => Compactable (Maybe a) where
  compact str Nothing = compactAppendOne str Nothing
  compact str (Just v) = do
    !v' <- appendRec str v
    compactAppendOne str (Just v')

instance (Compactable a, Compactable b) => Compactable (Either a b) where
  compact str (Left l) = do
    !l' <- appendRec str l
    compactAppendOne str (Left l')
  compact str (Right r) = do
    !r' <- appendRec str r
    compactAppendOne str (Right r')

instance Compactable Int where
  compact str v = compactAppendOne str v

instance Compactable Char where
  compact str v = compactAppendOne str v

instance Compactable Float where
  compact str v = compactAppendOne str v

instance Compactable Word where
  compact str v = compactAppendOne str v

instance Compactable Integer where
  compact = defaultCompactNFData

instance Compactable Double where
  compact = defaultCompactNFData