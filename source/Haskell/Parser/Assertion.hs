{-# LANGUAGE NamedFieldPuns #-}
module Parser.Assertion
  ( assertion
  , bound
  , precond
  , postcond
  , invariant
  , repInv
  , coupInv
  ) where
--------------------------------------------------------------------------------
import           AST.Expression
import           AST.Type
import           Error              as PE
import           Location
import           Parser.Declaration
import           Parser.Expression
import           Parser.Monad
import           Parser.State
import           Parser.Type
import           Token
--------------------------------------------------------------------------------
import           Control.Lens       ((%=))
import           Control.Monad      (unless, void)
import           Data.Sequence      ((|>))
import           Text.Megaparsec    (ParseError, between, lookAhead, manyTill,
                                     withRecovery)
--------------------------------------------------------------------------------

bound :: Parser (Maybe Expression)
bound = between (match TokLeftBound) (match' TokRightBound) (declarative bound')

  where
    bound' = do
      expr <- withRecovery recover expression
      case expr of
        Nothing -> pure Nothing
        Just Expression { loc = Location (from, _) , expType }
          | expType =:= GInt -> pure expr
          | otherwise -> do
            putError from $ BadBoundType expType
            pure Nothing

    recover :: ParseError TokenPos Error -> Parser (Maybe a)
    recover err = do
      errors %= (|> err)
      void . manyTill anyToken . lookAhead . match $ TokRightBound
      pure Nothing


assert :: Token -> Token -> Parser (Maybe Expression)
assert open close = between (match' open) (match' close) (declarative $ assert'' close)

assert' :: Token -> Token -> Parser (Maybe Expression)
assert' open close = between (match open) (match' close) (declarative $ assert'' close)
                           -- ^^^^^ this match is not obligatory
assert'' close = do
  expr <- withRecovery recover expression
  case expr of
    Nothing -> pure Nothing
    Just Expression { loc = Location (from, _), expType }
      | expType =:= GBool -> pure expr
      | otherwise -> do
        putError from $ BadAssertType expType
        pure Nothing
  where 

    recover :: ParseError TokenPos Error -> Parser (Maybe a)
    recover err = do
      errors %= (|> err)
      void . manyTill anyToken . lookAhead . match $ close
      pure Nothing

precond, postcond, assertion, invariant, repInv :: Parser (Maybe Expression)
precond   = assert  TokLeftPre   TokRightPre
postcond  = assert  TokLeftPost  TokRightPost
assertion = assert' TokLeftBrace TokRightBrace
invariant = assert  TokLeftInv   TokRightInv
repInv    = assert  TokLeftRep   TokRightRep
coupInv   = assert  TokLeftAcopl TokRightAcopl
