module MyTypeError where

import Location
import Token
import Data.Text as T

data MyTypeError = RepSymbolError { symbol      :: T.Text
                                  , preLocation :: Location
                                  , actLocation :: Location
                                  }
               deriving (Read, Show)
