module Parser.Program
  ( program
  ) where


-------------------------------------------------------------------------------
import           AST.Program
import           Graciela
import qualified MyParseError        as PE
import           Parser.ADT
import           Parser.Instruction (block)
import           Parser.Procedure   
import           Parser.Token
import           Parser.State
import           SymbolTable         (openScope, closeScope)
import           Location            (Location(..))
import           Token
import           Type
-------------------------------------------------------------------------------
import qualified Control.Monad       as M
import           Control.Lens        ((%=))
import qualified Data.Text           as T
import           Text.Megaparsec     hiding (Token)
-------------------------------------------------------------------------------

-- MainProgram -> 'program' Id 'begin' ListDefProc Block 'end'
mainProgram :: Graciela Program
mainProgram = do
  from <- getPosition
  match TokProgram
  id <- identifier
  match TokBegin

  decls <- listDefProc
  body  <- block
  match TokEnd
  eof
  to <- getPosition
  return (Program id (Location(from, to)) decls body)
  
      -- <|> do --genNewError eof PE.LexEnd
      --        return (AST from from GError (EmptyAST))


-- Program -> Abstract Program
-- Program -> MainProgram
{- The program consists in a set of Abstract Data Types, Data Types and a main program -}
program :: Graciela Program
program = do
  pos <- getPosition
  symbolTable %= openScope pos
  many (abstractDataType <|> dataType) -- Por ahora debe haber un programa
  program' <- mainProgram              -- principal al final del archivo
  symbolTable %= closeScope pos
  return program'
