module Expression where

import Control.Monad.Identity (Identity)
import qualified Control.Applicative as AP
import qualified Text.Parsec.Pos     as P
import qualified Data.Text.Read      as TR
import qualified Control.Monad       as M
import qualified Data.Monoid         as DM
import qualified Data.Text           as T
import MyParseError                  as PE
import ParserState                   as PS
import Text.Parsec.Error
import Text.Parsec
import TokenParser
import Location
import Token
import Lexer
import State
import Type
import AST



listExp :: MyParser Token -> MyParser Token -> MyParser (Maybe [AST ()])
listExp follow recSet = do  lookAhead follow
                            return $ return $ []
                        <|> ( do e     <- expr (follow <|> parseComma) (recSet <|> parseComma)
                                 lexp  <- listExpAux follow recSet
                                 return(AP.liftA2 (:) e lexp)
                            )
                        <|> (do err <- genNewError (recSet) (TokenRP)
                                return $ Nothing
                            )



listExpAux :: MyParser Token -> MyParser Token -> MyParser (Maybe [AST ()])
listExpAux follow recSet = do lookAhead follow
                              return $ return $ []
                           <|> ( do parseComma
                                    e  <- expr (follow <|> parseComma) (recSet <|> parseComma)
                                    lexp  <- listExpAux follow recSet
                                    return(AP.liftA2 (:) e lexp)
                               )
                           <|> (do err <- genNewError (recSet) (TokenRP)
                                   return $ Nothing
                               )



expr :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
expr follow recSet =  do lookAhead(follow)
                         return $ Nothing
                      
                      <|> exprLevel1 follow recSet



exprLevel1 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel1 follow recSet = do e <- exprLevel2 (follow <|> parseTokEqual) (recSet <|> parseTokEqual)
                              do pos <- getPosition
                                 do (lookAhead (follow) >> return e)
                                    <|> do parseTokEqual
                                           e' <- exprLevel1 follow recSet
                                           return(AP.liftA3 (Relational Equal (getLocation pos)) e e' (return ()))  
                                    
                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing



exprLevel2 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel2 follow recSet = do e <- exprLevel3 (follow <|> parseTokImplies <|> parseTokConse) (recSet <|> parseTokImplies <|> parseTokConse)
                              do pos <- getPosition
                                 do (lookAhead (follow) >> return e)
                                    <|> do parseTokImplies
                                           e' <- exprLevel2 follow recSet
                                           return(AP.liftA3 (Relational Implies (getLocation pos)) e e' (return ()))                                    
                                    
                                    <|> do parseTokConse
                                           e' <- exprLevel2 follow recSet
                                           return(AP.liftA3 (Relational Conse (getLocation pos)) e e' (return ()))      
                                    
                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing



exprLevel3 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel3 follow recSet = do e <- exprLevel4(follow <|> parseOr) (recSet <|> parseOr)
                              do pos <- getPosition
                                 do (lookAhead (follow) >> return e)
                                    <|> do parseOr
                                           e' <- exprLevel3 follow recSet
                                           return(AP.liftA3 (Boolean Dis (getLocation pos)) e e' (return ())) 
                                    
                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing
 


exprLevel4 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel4 follow recSet = do e <- exprLevel5 (follow <|>  parseAnd) (recSet <|> parseAnd)
                              do pos <- getPosition
                                 do (lookAhead (follow) >> return e)
                                    <|> do parseAnd
                                           e' <- exprLevel4 follow recSet
                                           return(AP.liftA3 (Boolean Con (getLocation pos)) e e' (return ()))
                                   
                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing



exprLevel5 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel5 follow recSet = do e <- exprLevel6 (follow <|> parseEqual <|> parseNotEqual) (recSet <|> parseEqual <|> parseNotEqual)
                              do pos <- getPosition
                                 do (lookAhead (follow) >> return e)
                                    <|> do parseEqual
                                           e' <- exprLevel5 follow recSet
                                           return(AP.liftA3 (Relational Equ (getLocation pos)) e e' (return ()))
                                   
                                    <|> do parseNotEqual
                                           e' <- exprLevel5 follow recSet
                                           return(AP.liftA3 (Relational Ine (getLocation pos)) e e' (return ()))              
                                    
                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing



followExprLevelRel = parseTokLess <|> parseTokGreater <|> parseTokLEqual <|> parseTokGEqual



exprLevel6 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel6 follow recSet = do e <- exprLevel7 (follow <|> followExprLevelRel) (recSet <|> followExprLevelRel)
                              do pos <- getPosition
                                 do (lookAhead (follow) >> return e)
                                    <|> do parseTokLess
                                           e' <- exprLevel5 follow recSet
                                           return(AP.liftA3 (Relational Less (getLocation pos)) e e' (return ()))
                                        
                                    <|> do parseTokLEqual
                                           e' <- exprLevel5 follow recSet
                                           return(AP.liftA3 (Relational LEqual (getLocation pos)) e e' (return ()))
                                        
                                    <|> do parseTokGreater
                                           e' <- exprLevel5 follow recSet
                                           return(AP.liftA3 (Relational Greater (getLocation pos)) e e' (return ()))
                                        
                                    <|> do parseTokGEqual
                                           e' <- exprLevel5 follow recSet
                                           return(AP.liftA3 (Relational GEqual (getLocation pos)) e e' (return ()))

                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing



exprLevel7 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel7 follow recSet =  do t <- exprLevel8 (follow <|> parsePlus <|> parseMinus) (recSet  <|> parsePlus <|> parseMinus)
                               do pos <- getPosition
                                  do (lookAhead(follow) >> return t)
                                     <|> do parsePlus
                                            e <- exprLevel7 follow recSet
                                            return $ AP.liftA3 (Arithmetic Sum (getLocation pos)) t e (return ())
                                     
                                     <|> do parseMinus
                                            e <- exprLevel7 follow recSet
                                            return $ AP.liftA3 (Arithmetic Sub (getLocation pos)) t e (return ())
                                     
                                     <|> do genNewError (recSet) (Operator)
                                            return $ Nothing



exprLevel8 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel8 follow recSet = do p <- exprLevel9 (follow <|> parseSlash <|> parseStar <|> parseTokMod) (recSet <|> parseSlash <|> parseStar <|> parseTokMod)
                              do pos <- getPosition
                                 do (lookAhead(follow) >> return p)
                                    <|> do parseSlash
                                           e <- exprLevel8 follow recSet
                                           return $ AP.liftA3 (Arithmetic Div (getLocation pos)) p e (return ())
                                    
                                    <|> do parseStar
                                           e <- exprLevel8 follow recSet
                                           return $ AP.liftA3 (Arithmetic Mul (getLocation pos)) p e (return ())
                                    
                                    <|> do parseTokMod
                                           e <- exprLevel8 follow recSet
                                           return $ AP.liftA3 (Arithmetic Mod (getLocation pos)) p e (return ())
                                    
                                    <|> do genNewError (recSet) (Operator)
                                           return $ Nothing



exprLevel9 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel9 follow recSet = do p <- exprLevel10 (follow <|> parseTokAccent) (recSet <|> parseTokAccent)
                              do pos <- getPosition
                                 do  (lookAhead(follow) >> return p)        
                                     <|> do parseTokAccent
                                            e <- exprLevel9 follow recSet
                                            return $ AP.liftA3 (Arithmetic Exp (getLocation pos)) p e (return ())
                                     
                                     <|> do genNewError (recSet) (Operator)
                                            return $ Nothing
            


{-| La función factor follow se encarga de consumir una expresión simple.
    Ésta puede ser un número, letra, cadena de caracteres, llamada a función,
    etc.
 -}
exprLevel10 :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST()) )
exprLevel10 follow recSet = do do pos <- getPosition
                                  do parseLeftParent
                                     e <- expr (parseRightParent) (parseRightParent)
                                     do  try(parseRightParent >>= return . return e)
                                         <|> do genNewError (recSet) (TokenRP)
                                                return $ Nothing
                                  
                                     <|> (do n <- number
                                             return $ return $ Int (getLocation pos) n ()   
                                         )
                                     <|> do idp <- parseID
                                            do      lookAhead follow
                                                    return $ return $ ID (getLocation pos) idp ()
                                                <|> do parseLeftParent
                                                       lexp <- listExp (parseEnd <|> parseRightParent) (recSet <|> parseRightParent)
                                                       do parseRightParent
                                                          return $ (AP.liftA2 (FCallExp (getLocation pos) idp) lexp (return ()))
                                                          <|> do genNewError (recSet) (TokenRP)
                                                                 return $ Nothing
                                                        
                                                <|> do blist <- bracketsList follow recSet
                                                       return $ (AP.liftA2 (ArrCall (getLocation pos) idp) blist (return ()))

                                         
                                     <|> do parseMaxInt
                                            return $ return $ Constant (getLocation pos) True  True ()
                                     
                                     <|> do parseMinInt
                                            return $ return $ Constant (getLocation pos) True  False ()
                                     
                                     <|> do parseMaxDouble
                                            return $ return $ Constant (getLocation pos) False True ()
                                     
                                     <|> do parseMinDouble
                                            return $ return $ Constant (getLocation pos) False False ()
                                     
                                     <|> do e <- parseBool
                                            return $ return $ Bool (getLocation pos) e ()
                                     
                                     <|> do e <- parseChar
                                            return $ return $ Char (getLocation pos) e ()
                                     
                                     <|> do e <- parseString
                                            return $ return $ String (getLocation pos) e ()
                                     
                                     <|> do parseToInt
                                            parseLeftParent
                                            e <- expr parseRightParent parseRightParent
                                            parseRightParent
                                            return(AP.liftA2 (Convertion ToInt (getLocation pos)) e (return ()))
                                         
                                     <|> do parseToDouble
                                            parseLeftParent
                                            e <- expr parseRightParent parseRightParent
                                            parseRightParent 
                                            return(AP.liftA2  (Convertion ToDouble (getLocation pos)) e  (return ()))
                                         
                                     <|> do parseToString
                                            parseLeftParent
                                            e <- expr parseRightParent parseRightParent
                                            parseRightParent
                                            return(AP.liftA2  (Convertion ToString (getLocation pos)) e (return ()))
                                         
                                     <|> do parseToChar
                                            parseLeftParent
                                            e <- expr parseRightParent parseRightParent
                                            parseRightParent
                                            return(AP.liftA2  (Convertion ToChar (getLocation pos)) e (return ()))
                                         
                                     <|> do parseMinus
                                            e <- expr follow recSet
                                            return(AP.liftA2  (Unary Minus (getLocation pos)) e (return ()))
                                         
                                     <|> do parseTokAbs
                                            e <- expr follow recSet
                                            return(AP.liftA2  (Unary Abs (getLocation pos)) e (return ()))
                                         
                                     <|> do parseTokSqrt
                                            e <- expr follow recSet
                                            return(AP.liftA2  (Unary Sqrt (getLocation pos)) e (return ()))
                                         
                                     <|> do parseTokLength
                                            e <- expr follow recSet
                                            return(AP.liftA2  (Unary Length (getLocation pos)) e (return ()))
                                         
                                     <|> do parseTokNot
                                            e <- expr follow recSet
                                            return(AP.liftA2  (Unary Not (getLocation pos)) e (return ()))
                                         
                                     <|> quantification follow recSet
                                     <|> do genNewError (recSet) (Number)
                                            return $ Nothing



quantification follow recSet = do parseTokLeftPer
                                  op <- parseOpCuant
                                  id <- parseID
                                  parseColon
                                  r <- expr(parseColon) (recSet <|> parseColon)
                                  parseColon
                                  t <- expr(parseTokRightPer) (recSet <|> parseTokRightPer)
                                  parseTokRightPer
                                  pos <- getPosition
                                  return(AP.liftA3 (Quant op id (getLocation pos)) r t (return ()))



parseOpCuant = parseTokExist
               <|> parseTokMod
               <|> parseTokMax
               <|> parseTokMin
               <|> parseTokForall
               <|> parseTokNotExist
               <|> parseTokSigma
               <|> parseTokPi
               <|> parseTokUnion



bracketsList follow recSet = do  lookAhead follow
                                 return $ return []
                                 <|> do parseLeftBracket
                                        e <- expr parseRightBracket parseRightBracket
                                        do parseRightBracket
                                           lexp <- bracketsList follow recSet
                                           return(AP.liftA2 (:) e lexp)
                                           -- FALTA ARREGLAR EL CASO RARO
                                           -- Modemos levantarnos del error con un hazte el loco  
                                           <|> do err <- genNewError (follow <|> parseLeftBracket) (TokenRB)
                                                  return $ Nothing   
