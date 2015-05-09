module Location where

import Text.Parsec

data Location = Location { line :: Int, column :: Int, name :: String }
  deriving (Read, Eq) 


instance Show Location where
	show (Location line column name) ="Archivo " ++show name++ ": línea " ++show line++ ", columna " ++show column


getLocation pos = Location (sourceLine pos) (sourceColumn pos) (sourceName pos)


