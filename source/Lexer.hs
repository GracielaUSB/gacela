module Lexer where

import Text.Parsec
import Text.Parsec.Error
import Control.Monad.Identity (Identity)
import qualified Control.Applicative as AP
import qualified Data.Text as T
import Token



tryString = try . string

pPlus         = oneOf "+\43"
pMinus        = oneOf "-\45"
pStar         = oneOf "*\215"
pSlash        = oneOf "/\247"
pComma        = oneOf ",\44"
pLeftParent   = oneOf "(\40"
pRightParent  = oneOf ")\41"
pLeftBracket  = oneOf "[\91"
pRightBracket = oneOf "]\93"
pVerticalBar  = oneOf "|\124"
pSemicolon    = oneOf ";\59"
pColon        = oneOf ":\58" 
pLeftBrace    = oneOf "{\123"
pRightBrace   = oneOf "}\125"
pLess         = oneOf "<\60"
pGreater      = oneOf ">\62"
pEqual        = oneOf "=\61"
pNot          = oneOf "!\33"
pPercent      = oneOf "%\37"
pAccent       = oneOf "^\94"
pLogicalAnd   = tryString "/\\" <|> tryString "\8743" 
pLogicalOr    = tryString "\\/" <|> tryString "\8744"
pNotEqual     = tryString "!="  <|> tryString "\8800"
pLessEqual    = tryString "<="  <|> tryString "\8804"
pGreaterEqual = tryString ">="  <|> tryString "\8805"
pImplies      = tryString "==>" <|> tryString "\8658"
pConsequent   = tryString "<==" <|> tryString "\8656"
pEquiv        = tryString "=="  <|> tryString "\8801"
pNotEqiv      = tryString "=/=" <|> tryString "\8802"
pReturn       = tryString ">>"  <|> tryString "\8811"
pAsig         = tryString ":="   
pProgram      = tryString "program"
pArrow        = tryString "->"    <|> tryString "\8594"
pLeftPre      = tryString "{pre"
pRightPre     = tryString "pre}"
pLeftPost     = tryString "{post"
pRightPost    = tryString "post}"
pLeftBound    = tryString "{bound"
pRightBound   = tryString "bound}"
pLeftA        = tryString "{a"
pRightA       = tryString "a}"
pLeftInv      = tryString "{inv"
pRightInv     = tryString "inv}"
pPre          = tryString "pre"
pPost         = tryString "post"
pBound        = tryString "bound"
pFunc         = tryString "func"
pProc         = tryString "proc"
pIn           = tryString "in"
pOut          = tryString "out"
pInOut        = tryString "inout"
pWith         = tryString "with"
pMod          = tryString "mod"
pMax          = tryString "max"
pMin          = tryString "min"
pForall       = tryString "forall"   <|> tryString "\8704" 
pExist        = tryString "exist"    <|> tryString "\8707" 
pNotExist     = tryString "notExist" <|> tryString "\8708"
pSigma        = tryString "sigma"    <|> tryString "\8721" 
pPi           = tryString "pi"       <|> tryString "\960"
pUnion        = tryString "union"    <|> tryString "\8746"
pIf           =  tryString "if"
pFi           =  tryString "fi"
pInv          = tryString "inv"
pDo           = tryString "do"
pOd           = tryString "od"
pGcd          = tryString "gcd"
pAbs          = tryString "abs"
pSqrt         = tryString "sqrt" <|> tryString "\8730" 
pLength       = tryString "length"
pVar          = tryString "var"
pConst        = tryString "const"
pAbort        = tryString "abort"
pRandom       = tryString "random"
pSkip         = tryString "skip"
pWrite        = tryString "write"
pWriteln      = tryString "writeln"
pRead         = tryString "read"
pToInt        = tryString "toInt"
pToDouble     = tryString "toDouble"
pToChar       = tryString "toChar"
pToString     = tryString "toString"
pType         = tryString "boolean"  <|> tryString "int"    <|> tryString "double"
                <|> tryString "char" <|> tryString "string" <|> tryString "array"  
pBool         = tryString "True"     <|> tryString "False"
pMIN_INT      = tryString "MIN_INT"
pMIN_DOUBLE   = tryString "MIN_DOUBLE"
pMAX_INT      = tryString "MAX_INT"
pMAX_DOUBLE   = tryString "MAX_DOUBLE"
pOf           = tryString "of"



lexer :: Parsec T.Text () ([TokenPos])
lexer = do pos <- getPosition    
           do  (eof >> spaces >> return ([(TokEnd, pos)]))
               <|> (do tok <- (   (pPlus         >> spaces >> return (TokPlus))
                              <|> (pArrow        >> spaces >> return (TokArrow))
                              <|> (pLeftPre      >> spaces >> return (TokLeftPre))
                              <|> (pRightPre     >> spaces >> return (TokRightPre))
                              <|> (pLeftPost     >> spaces >> return (TokLeftPost))
                              <|> (pRightPost    >> spaces >> return (TokRightPost))
                              <|> (pLeftBound    >> spaces >> return (TokLeftBound))
                              <|> (pRightBound   >> spaces >> return (TokRightBound))
                              <|> (pLeftA        >> spaces >> return (TokLeftA))
                              <|> (pRightA       >> spaces >> return (TokRightA))
                              <|> (pLeftInv      >> spaces >> return (TokLeftInv))
                              <|> (pRightInv     >> spaces >> return (TokRightInv))
                              <|> (pMinus        >> spaces >> return (TokMinus))
                              <|> (pStar         >> spaces >> return (TokStar))
                              <|> (pSlash        >> spaces >> return (TokSlash))
                              <|> (pComma        >> spaces >> return (TokComma))
                              <|> (pLeftParent   >> spaces >> return (TokLeftParent))
                              <|> (pRightParent  >> spaces >> return (TokRightParent))
                              <|> (pPercent      >> spaces >> return (TokPercent))
                              <|> (pAccent       >> spaces >> return (TokAccent))
                              <|> (pLogicalAnd   >> spaces >> return (TokLogicalAnd))
                              <|> (pLogicalOr    >> spaces >> return (TokLogicalOr))
                              <|> (pNotEqual     >> spaces >> return (TokNotEqual))
                              <|> (pImplies      >> spaces >> return (TokImplies))
                              <|> (pConsequent   >> spaces >> return (TokConsequent))
                              <|> (pLessEqual    >> spaces >> return (TokLessEqual))
                              <|> (pGreaterEqual >> spaces >> return (TokGreaterEqual))
                              <|> (pEquiv        >> spaces >> return (TokEquiv))
                              <|> (pNotEqiv      >> spaces >> return (TokNotEqiv))
                              <|> (pReturn       >> spaces >> return (TokReturn))
                              <|> (pAsig         >> spaces >> return (TokAsig))
                              <|> (pLess         >> spaces >> return (TokLess))
                              <|> (pGreater      >> spaces >> return (TokGreater))
                              <|> (pEqual        >> spaces >> return (TokEqual))
                              <|> (pNot          >> spaces >> return (TokNot))
                              <|> (pProgram      >> spaces >> return (TokProgram))
                              <|> (pLeftBracket  >> spaces >> return (TokLeftBracket))
                              <|> (pRightBracket >> spaces >> return (TokRightBracket))
                              <|> (pVerticalBar  >> spaces >> return (TokVerticalBar))
                              <|> (pSemicolon    >> spaces >> return (TokSemicolon))
                              <|> (pColon        >> spaces >> return (TokColon))
                              <|> (pLeftBrace    >> spaces >> return (TokLeftBrace))
                              <|> (pRightBrace   >> spaces >> return (TokRightBrace))
                              <|> (pPre          >> spaces >> return (TokPre))
                              <|> (pPost         >> spaces >> return (TokPost))
                              <|> (pBound        >> spaces >> return (TokBound))
                              <|> (pFunc         >> spaces >> return (TokFunc))
                              <|> (pProc         >> spaces >> return (TokProc))
                              <|> (pIn           >> spaces >> return (TokIn))
                              <|> (pOut          >> spaces >> return (TokOut))
                              <|> (pInOut        >> spaces >> return (TokInOut))
                              <|> (pWith         >> spaces >> return (TokWith))
                              <|> (pMod          >> spaces >> return (TokMod))
                              <|> (pMax          >> spaces >> return (TokMax))
                              <|> (pMin          >> spaces >> return (TokMin))
                              <|> (pForall       >> spaces >> return (TokForall))
                              <|> (pExist        >> spaces >> return (TokExist))
                              <|> (pNotExist     >> spaces >> return (TokNotExist))
                              <|> (pSigma        >> spaces >> return (TokSigma))
                              <|> (pPi           >> spaces >> return (TokPi))
                              <|> (pUnion        >> spaces >> return (TokUnion))
                              <|> (pIf           >> spaces >> return (TokIf))
                              <|> (pFi           >> spaces >> return (TokFi))
                              <|> (pInv          >> spaces >> return (TokInv))
                              <|> (pDo           >> spaces >> return (TokDo))  
                              <|> (pOd           >> spaces >> return (TokOd))
                              <|> (pGcd          >> spaces >> return (TokGcd))
                              <|> (pAbs          >> spaces >> return (TokAbs))
                              <|> (pSqrt         >> spaces >> return (TokSqrt))
                              <|> (pLength       >> spaces >> return (TokLength))
                              <|> (pVar          >> spaces >> return (TokVar))
                              <|> (pConst        >> spaces >> return (TokConst))
                              <|> (pAbort        >> spaces >> return (TokAbort))
                              <|> (pRandom       >> spaces >> return (TokRandom))
                              <|> (pSkip         >> spaces >> return (TokSkip))
                              <|> (pWrite        >> spaces >> return (TokWrite))
                              <|> (pWriteln      >> spaces >> return (TokWriteln))
                              <|> (pRead         >> spaces >> return (TokRead))
                              <|> (pToInt        >> spaces >> return (TokToInt))
                              <|> (pToDouble     >> spaces >> return (TokToDouble))    
                              <|> (pToChar       >> spaces >> return (TokToChar))
                              <|> (pToString     >> spaces >> return (TokToString))
                              <|> (pType         >> spaces >> return (TokType))
                              <|> (pBool         >> spaces >> return (TokBool))
                              <|> (pMIN_INT      >> spaces >> return (TokMIN_INT))
                              <|> (pMIN_DOUBLE   >> spaces >> return (TokMIN_DOUBLE))
                              <|> (pMAX_INT      >> spaces >> return (TokMAX_INT))
                              <|> (pMAX_DOUBLE   >> spaces >> return (TokMAX_DOUBLE))
                              <|> (pOf           >> spaces >> return (TokOf))
                              <|> ((many1 digit)  AP.<* spaces >>= return . (TokInteger . read))
                              <|> (anyChar        AP.<* spaces >>= return . (TokError . T.singleton)))
                       fmap ((tok, pos) :) lexer)

