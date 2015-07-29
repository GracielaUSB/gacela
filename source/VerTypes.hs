module VerTypes where

import qualified Control.Monad.RWS.Strict as RWSS
import qualified Data.Sequence            as DS
import qualified Data.Text                as T
import MyTypeError                   
import Contents
import SymbolTable
import Data.Maybe
import TypeState
import Location
import Type
import AST


checkListType :: Type -> Bool -> Type -> Bool 
checkListType _ False _ = False
checkListType x True  y = x == y
 

checkError :: Type -> Type -> Type
checkError acc t = let check = verType acc t
                   in case acc of
                      { MyError   -> MyError 
                      ; MyEmpty   -> case check of
                                     { MyError   -> MyError
                                     ; otherwise -> MyEmpty
                                     }  
                      ; otherwise -> case check of
                                     { MyError   -> MyError
                                     ; otherwise -> check
                                     }  
                      }


verType :: Type -> Type -> Type
verType MyError _  = MyError 
verType _  MyError = MyError 
verType x  y       = if (x == y) then x else MyEmpty


verArithmetic :: Type -> Type -> Location -> OpNum -> MyVerType
verArithmetic ltype rtype loc op =
    let checkT = verType ltype rtype
    in case checkT of
       { MyInt     -> return MyInt
       ; MyFloat   -> return MyFloat
       ; MyError   -> return MyError
       ; otherwise -> addTypeError $ ArithmeticError ltype rtype op loc
       }                   


verBoolean :: Type -> Type -> Location -> OpBool -> MyVerType
verBoolean ltype rtype loc op =
    let checkT = verType ltype rtype
    in case checkT of
       { MyBool    -> return MyBool
       ; MyError   -> return MyError
       ; otherwise -> addTypeError $ BooleanError ltype rtype op loc
       }                   


verRelational :: Type -> Type -> Location -> OpRel -> MyVerType
verRelational ltype rtype loc op =
    let checkT = verType ltype rtype
    in case checkT of
       { MyError   -> return MyError
       ; MyEmpty   -> addTypeError $ RelationalError ltype rtype op loc
       ; otherwise -> return MyBool
       }


verConvertion :: Conv -> MyVerType
verConvertion ToInt    = return MyInt   
verConvertion ToDouble = return MyFloat 
verConvertion ToString = return MyString
verConvertion ToChar   = return MyChar  


verWrite :: Type -> MyVerType
verWrite  MyError = return MyError 
verWrite  _       = return MyEmpty


verUnary :: OpUn -> Type -> Location -> MyVerType
verUnary _     MyError _   = return MyError

verUnary Minus MyInt   loc = return MyInt  
verUnary Minus MyFloat loc = return MyFloat
verUnary Minus errType loc = addTypeError $ UnaryError errType Minus loc

verUnary Not   MyBool  loc = return MyBool 
verUnary Not   errType loc = addTypeError $ UnaryError errType Not   loc

verUnary Abs   MyInt   loc = return MyInt  
verUnary Abs   MyFloat loc = return MyFloat
verUnary Abs   errType loc = addTypeError $ UnaryError errType Abs   loc

verUnary Sqrt  MyInt   loc = return MyInt  
verUnary Sqrt  MyFloat loc = return MyFloat
verUnary Sqrt  errType loc = addTypeError $ UnaryError errType Sqrt  loc


verGuardAction :: Type -> Type -> MyVerType
verGuardAction assert action = 
    case assert == MyBool && action == MyEmpty of
    { True  -> return MyEmpty
    ; False -> return MyError
    }


verGuard :: Type -> Type -> Location -> MyVerType
verGuard exp action loc =
    case action of
    { MyError -> return MyError
    ; MyEmpty -> case exp of
                 { MyError   -> return MyError
                 ; MyBool    -> return MyEmpty
                 ; otherwise -> addTypeError $ GuardError exp loc
                 }
    }


verGuardExp :: Type -> Type -> Location -> MyVerType
verGuardExp exp action loc =
    case action of
    { MyError   -> return MyError
    ; otherwise -> case exp of
                   { MyError   -> return MyError
                   ; MyBool    -> return action
                   ; otherwise -> addTypeError $ GuardError exp loc
                   }                      
    }


verDefProc :: [Type] -> Type -> Type -> Type -> [Type] -> MyVerType
verDefProc accs pre post bound decs = 
    let func = checkListType MyEmpty
    in case pre == MyBool && post == MyBool && 
            (foldl func True accs) && (and $ map (== MyEmpty) decs) of
       { True  -> return MyEmpty 
       ; False -> return MyError
       }


verBlock :: [Type] -> MyVerType
verBlock accs =
    let func = checkListType MyEmpty
    in case (foldl func True accs) of
       { True  -> return MyEmpty
       ; False -> return MyError
       }


verProgram :: [Type] -> [Type] -> MyVerType
verProgram defs accs =
    let func = checkListType MyEmpty
    in case (foldl func True defs) && (foldl func True accs) of
       { True  -> return $ MyEmpty
       ; False -> return $ MyError
       }


verCond :: [Type] -> Location -> MyVerType
verCond guards loc =
    let checkSame  = (\acc t -> if acc == t then acc else MyError)  
        checkT     = foldl1 checkSame guards               
    in case (foldl checkError MyEmpty guards) of
       { MyError   -> return MyError
       ; otherwise -> case checkT of
                      { MyError   -> addTypeError $ CondError loc   
                      ; MyEmpty   -> return MyEmpty
                      ; otherwise -> return checkT  
                      }
       }


verState :: Type -> Location -> StateCond -> MyVerType
verState expr loc stateCond =
    case expr of
    { MyError   -> return MyError
    ; otherwise -> let checkT = case stateCond of
                                { Bound     -> MyInt
                                ; otherwise -> MyBool 
                                }
                   in case expr == checkT of
                      { True  -> return expr 
                      ; False -> addTypeError $ StateError expr stateCond loc 
                      }
    }


verRept :: [Type] -> Type -> Type -> MyVerType
verRept guard inv bound =
    let func = checkListType MyEmpty
    in case (foldl func True guard) && inv == MyBool && bound == MyInt of
       { True  -> return MyEmpty 
       ; False -> return MyError
       }


verRandom :: T.Text -> Type -> Location -> MyVerType
verRandom name t loc =
    case t == MyInt || t == MyFloat of
    { True  -> return t 
    ; False -> addTypeError $ RanError name t loc
    }


verQuant :: OpQuant -> Type -> Type -> Location -> MyVerType
verQuant op range term loc = 
    case op of
    { ForAll    -> case range == MyBool && term == MyBool of
                   { True  -> return MyBool 
                   ; False -> addQuantBoolError op range term loc
                   }  
    ; Exists    -> case range == MyBool && term == MyBool of
                   { True  -> return MyBool 
                   ; False -> addQuantBoolError op range term loc
                   }
    ; Product   -> case range == MyBool && term == MyInt of 
                   { True  -> return MyBool 
                   ; False -> addQuantIntError op range term loc
                   }
    ; Summation -> case range == MyBool && term == MyInt of
                   { True  -> return MyBool 
                   ; False -> addQuantIntError op range term loc
                   }
    ; Maximum   -> case range == MyBool && term == MyInt of
                   { True  -> return MyBool 
                   ; False -> addQuantIntError op range term loc
                   }
    ; Minimum   -> case range == MyBool && term == MyInt of
                   { True  -> return MyBool 
                   ; False -> addQuantIntError op range term loc
                   }
    }


verConsAssign :: [(T.Text, Location)] -> Location -> [Type] -> Type -> MyVerType
verConsAssign xs loc ts t =
    let f (((id, loc'), t')) =
          case t' /= t of
          { True  -> if t' == MyError then return MyError else addTypeDecError id loc' t' t
          ; False -> return MyEmpty
          }
    in case length xs /= length ts of
       { True  -> addDifSizeDecError loc
       ; False -> do r <- fmap and $ fmap (map (== MyEmpty)) $ mapM f (zip xs ts)
                     case r of
                     { True  -> return MyEmpty
                     ; False -> return MyError
                     }
       }


verCallExp :: T.Text -> SymbolTable -> [Type] -> Location -> [Location] -> MyVerType
verCallExp name sbc args loc locarg =
    do sb <- RWSS.ask
       case (lookUpRoot name sb) of
       { Nothing -> addUndecFuncError name True loc
       ; Just (FunctionCon _ t ln sb)  -> 
           case t of
           { MyFunction args' ts -> 
               let wtL = length args
                   prL = length args'
               in case wtL /= prL of
                  { True  -> addNumberArgsError name True wtL prL loc
                  ; False -> let t = zip args args'
                             in case (and $ map (uncurry (==)) $ t) of
                                { True  -> do r <- validFuncArgs ln args locarg sb sbc
                                              case r of
                                              { True  -> return ts
                                              ; False -> return MyError
                                              }
                                ; False -> do mapM_ (\ ((arg, arg'), larg) -> 
                                                case arg /= arg' of
                                                { True  -> addFunArgError name True arg' arg larg 
                                                ; False -> return MyEmpty
                                                } ) (zip t locarg) 
                                              return $ MyError
                                }
                  }
            ; otherwise -> addUndecFuncError name True loc
            }
       }


----------------------------------------------------
validFuncArgs :: [T.Text] -> [Type] -> [Location] -> SymbolTable -> SymbolTable -> 
                     RWSS.RWS (SymbolTable) (DS.Seq (MyTypeError)) () Bool
validFuncArgs lnp lnc locarg sbp sbc = return True
               


verProcCall :: T.Text -> SymbolTable -> [AST Type] -> Location -> [Location] -> MyVerType
verProcCall name sbc args'' loc locarg = 
    do sb <- RWSS.ask
       case (lookUpRoot name sb) of
       { Nothing -> addUndecFuncError name False loc
       ; Just (ProcCon _ t ln sb) -> 
           case t of
           { MyProcedure args' ->
               let wtL = length args''
                   prL = length args'
               in case wtL /= prL of
                  { True  -> addNumberArgsError name False wtL prL loc
                  ; False -> let args = map tag args''
                                 t    = zip args args'
                             in case (and $ map (uncurry (==)) $ t) of   
                                { True  -> do r <- validProcArgs ln args'' locarg sb sbc
                                              case r of
                                              { True  -> return MyEmpty
                                              ; False -> return MyError
                                              }
                                ; False -> do mapM_ (\ ((arg, arg'), larg) -> 
                                                case arg /= arg' of
                                                { True  -> addFunArgError name False arg' arg larg 
                                                ; False -> return MyEmpty 
                                                } ) (zip t locarg) 
                                              return $ MyError
                                }

                  }
           ; otherwise -> addUndecFuncError name False loc
           }
        }


validProcArgs :: [T.Text] -> [AST Type] -> [Location] -> SymbolTable -> SymbolTable -> 
                     RWSS.RWS (SymbolTable) (DS.Seq (MyTypeError)) () Bool
validProcArgs lnp lnc locarg sbp sbc = 
    let lat = map getProcArgType $  map fromJust $ map ((flip checkSymbol) sbp) lnp
        lvt = map (isASTLValue sbc) lnc
        xs  = zip lat lvt
    in fmap and $ mapM compare (zip xs (zip lnc locarg))
      where
        compare ((Just Out, False), (id, loc))   = 
            do addInvalidPar id loc
               return False
        compare ((Just InOut, False), (id, loc)) = 
            do addInvalidPar id loc
               return False
        compare _                                =
               return True


isASTLValue :: SymbolTable -> AST a -> Bool
isASTLValue sb id =
  case astToId id of
  { Nothing -> False
  ; Just t  -> case (checkSymbol t sb) of
               { Nothing -> False -- Esto es un error grave, significa que una variable sin verificacion de contexto llego a la verificacion de tipos
               ; Just c  -> isLValue c
               }
  } 


addLAssignError:: Location -> [MyTypeError] -> (((T.Text, Type), [Type]), Type) -> 
                    RWSS.RWS (SymbolTable) (DS.Seq (MyTypeError)) () [MyTypeError]
addLAssignError loc acc (((tok, (MyArray t tam)), expArrT), expT) = 
    do arrT <- verArrayCall tok expArrT (MyArray t tam) loc 
       case arrT of
       { MyError   -> return acc 
       ; otherwise -> case (checkListType arrT True expT) of 
                      { True  -> return acc 
                      ; False -> return $ acc ++ [AssignError tok arrT expT loc]
                      }  
       }

addLAssignError loc acc (((tok, t), _), expT) = 
    case (checkListType t True expT) of 
    { True  -> return acc 
    ; False -> return $ acc ++ [AssignError tok t expT loc]
    }  


verLAssign :: [Type] -> [(T.Text, Type)] -> [[Type]] -> Location -> MyVerType
verLAssign explist idlist expArrT loc = 
    do check <- RWSS.foldM (addLAssignError loc) [] $ zip (zip idlist expArrT) explist
       let checkError' = (\acc t -> if not(acc == MyError) && not(t == MyError) then MyEmpty else MyError)   
       case (foldl1 checkError' explist) of
       { MyError   -> return MyError
       ; otherwise -> case check of 
                      { []        -> return MyEmpty
                      ; otherwise -> do mapM_ addListError check
                                        return MyError
                      }
       }


verArrayCall :: T.Text -> [Type] -> Type -> Location -> MyVerType
verArrayCall name args t loc =
    let waDim = getDimention t 0
        prDim = length args
    in case (waDim == prDim) of
       { False -> addTypeError $ ArrayDimError name waDim prDim loc   
       ; True  -> case (foldl checkError MyInt args) of
                  { MyError   -> return MyError
                  ; MyInt     -> return $ getType t
                  ; otherwise -> let addError = (\acc expT -> 
                                       case (checkListType MyInt True expT) of 
                                       { True  -> acc 
                                       ; False -> acc ++ [ArrayCallError name expT loc]
                                       } )  
                                     check    = foldl addError [] args
                                 in do mapM_ addListError check
                                       return MyError
                  }
       }


verDefFun :: T.Text -> Type -> Type -> Location -> MyVerType
verDefFun name body bound loc =
    do sb <- RWSS.ask
       case lookUpRoot name sb of
       { Nothing -> addUndecFuncError name True loc
       ; Just c  -> case (symbolType c) of
                     { MyFunction _ tf -> case tf == body of
                                         { True  -> return MyEmpty
                                         ; False -> addRetFuncError name tf body loc
                                         }
                     ; otherwise       -> addUndecFuncError name True loc
                     } 
       }
