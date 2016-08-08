module Parser.Procedure
  ( listDefProc
  , function
  , procedure
  , paramType
  , procParam
  , procedureDeclaration
  ) where

-------------------------------------------------------------------------------
import           AST.Definition

import           Entry
import           Graciela
import           Location
import           MyParseError       as PE
import           Parser.Assertion
import           Parser.Declaration
import           Parser.Expression
import           Parser.Instruction
import           Parser.Token
import           Parser.Type
import           SymbolTable
import           Token
import           Type
-------------------------------------------------------------------------------
import           Control.Monad      (void, when)
import           Data.Functor       (($>))
import           Data.Monoid        ((<>))
import           Control.Lens       (use, (%=))
import qualified Data.Text          as T
import           Data.Maybe         (catMaybes)
import           Text.Megaparsec    ((<|>), many, notFollowedBy, sepBy, getPosition)
-------------------------------------------------------------------------------

listDefProc :: Graciela [Definition]
listDefProc = many (function <|> procedure)

function :: Graciela Definition
function  = do
  from <- getPosition
  match TokFunc

  id      <- identifier
  params  <- parens $ functionParameters `sepBy` match TokComma
  withRecovery TokArrow
  tname   <- identifier
  retType <- getType tname
  when (retType == GError) $
    genCustomError ("El tipo `" <> T.unpack tname <> "` no existe.")

  symbolTable %= openScope from
  withRecovery TokBegin
  body <- expression
  withRecovery TokEnd 
  to  <- getPosition
  let loc = Location (from, to)

  st  <- use symbolTable
  symbolTable %= closeScope to
  symbolTable %= insertSymbol id (Entry id loc (Function retType params st))

  let func = FunctionDef body retType
  return $ Definition loc id params st Nothing func
      -- <|> return (AST from from GError (EmptyAST))

  where
    functionParameters :: Graciela (T.Text, Type)
    functionParameters = do
        from <- getPosition
        id <- identifier
        withRecovery TokColon
        t  <- type'
        to <- getPosition
        let loc = Location(from,to)
        symbolTable %= insertSymbol id (Entry id loc (Argument In t))
        return (id, t)

procedure :: Graciela Definition
procedure = do
    from <- getPosition
    -- Parse the procedure signature. it most not be followed by an Arrow (->).
    match TokProc
    id <- identifierWithRecovery
    symbolTable %= openScope from
    params <- parens $ procParam `sepBy` match TokComma
    notFollowedBy $ match TokArrow
    -- Parse the procedure's body
    withRecovery TokBegin
    decls <- declarationBlock 
    pre   <- precondition 
    body  <- block 
    post  <- postcondition 
    withRecovery TokEnd
    -- Get the actual symbol table and build the ast and the entry of the procedure
    st    <- use symbolTable
    to    <- getPosition
    let loc = Location(from,to)
    symbolTable %= closeScope to
    if id /= errorId
      then do 
        symbolTable %= insertSymbol id (Entry id loc (Procedure params st))
        
        let proc = (ProcedureDef decls pre body post)
        return $ Definition loc id params st Nothing proc
      else 
        return $ BadDefinition loc

paramType :: Graciela (Maybe ArgMode)
paramType =  match TokIn    $> Just In
         <|> match TokInOut $> Just InOut
         <|> match TokOut   $> Just Out
         <|> match TokRef   $> Just Ref
         <|> return Nothing


procParam :: Graciela (T.Text, Type)
procParam = do
  from <- getPosition
  ptype <- paramType
  id  <- identifier
  withRecovery TokColon
  t   <- type'
  to <- getPosition
  let loc = Location(from,to)
  case ptype of
    Just x | t /= GError -> symbolTable %= insertSymbol id (Entry id loc (Argument In t))
    _  -> genCustomError ("Se debe especificar el comportamiento de la variable `"
                           <>T.unpack id<>"` (In, Out, InOut)")
  return (id, t)


-- ProcDecl -> 'proc' Id ':' '(' ListArgProc ')' Precondition Postcondition
procedureDeclaration :: Graciela Definition
procedureDeclaration = do
    from <- getPosition
    match TokProc
    id <- identifier
    symbolTable %= openScope from
    params <- parens . many $ procParam
    notFollowedBy $ match TokArrow
    pre  <- precondition
    post <- postcondition
    st   <- use symbolTable
    to   <- getPosition
    let loc = Location (from,to)
    symbolTable %= closeScope to
    symbolTable %= insertSymbol id (Entry id loc (Procedure params st))

    let proc = AbstractProcedureDef pre post
    return $ Definition loc id params st Nothing proc

-- Deberian estar en el lugar adecuando, hasta ahora aqui porq no le he usado en archivos q no dependen de Procedure

-- panicModeId :: Graciela Token -> Graciela T.Text
-- panicModeId token =
--         try identifier
--     <|> do t <- lookAhead
--            genNewError (return t) PE.IdError
--            return $ T.pack "No Id"
--     <|> do (t:_) <- anyToken `manyTill` lookAhead
--            genNewError (return $fst t) PE.IdError
--            return $ T.pack "No Id"


-- panicMode :: Graciela Token -> Graciela Token -> ExpectedToken -> Graciela ()
-- panicMode token err =
--         try (void token)
--     <|> do t <- lookAhead
--            genNewError (return t) err
--     <|> do (t:_) <- anyToken `manyTill` lookAhead
--            genNewError (return $ fst t) err
