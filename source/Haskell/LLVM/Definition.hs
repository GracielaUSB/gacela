{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE MultiWayIf               #-}
{-# LANGUAGE NamedFieldPuns           #-}
{-# LANGUAGE OverloadedStrings        #-}
{-# LANGUAGE PostfixOperators         #-}

module LLVM.Definition where
--------------------------------------------------------------------------------
import           AST.Declaration                     (Declaration)
import           AST.Definition
import           AST.Expression                      (Expression (..))
import qualified AST.Instruction                     as G (Instruction)
import           AST.Struct                          (Struct (..), Struct' (..))
import           AST.Type                            ((=:=))
import qualified AST.Type                            as T
import           Common
import           LLVM.Abort                          (abort, abortString)
import qualified LLVM.Abort                          as Abort (Abort (..))
import           LLVM.Boolean
import           LLVM.Declaration                    (declaration)
import           LLVM.Expression
import           LLVM.Instruction
import           LLVM.Monad
import           LLVM.State
import           LLVM.Type
import           LLVM.Warning                        (warn, warnString)
import qualified LLVM.Warning                        as Warning (Warning (Post, Pre))
import           Location
import qualified Location                            as L (pos)
import           Parser.Config
import           Treelike
--------------------------------------------------------------------------------
import           Control.Lens                        (use, (%=), (&), (.=))
import           Data.Array                          ((!))
import           Data.Foldable                       (toList)
import           Data.Map.Strict                     (Map)
import qualified Data.Map.Strict                     as Map
import           Data.Maybe                          (fromMaybe)
import           Data.Sequence                       as Seq (empty, fromList)
import qualified Data.Sequence                       as Seq (empty)
import           Data.Text                           (Text, pack, unpack)
import           Data.Word                           (Word32)
import           LLVM.General.AST                    (BasicBlock (..),
                                                      Named (..),
                                                      Parameter (..),
                                                      Terminator (..),
                                                      functionDefaults)
import qualified LLVM.General.AST                    as LLVM (Definition (..))
import           LLVM.General.AST.AddrSpace
import qualified LLVM.General.AST.CallingConvention  as CC (CallingConvention (C))
import qualified LLVM.General.AST.Constant           as C
import           LLVM.General.AST.Global             (Global (..),
                                                      functionDefaults)
import           LLVM.General.AST.Instruction
import           LLVM.General.AST.IntegerPredicate   (IntegerPredicate (EQ, SGE, SLT))
import           LLVM.General.AST.Linkage            (Linkage (Private))
import           LLVM.General.AST.Name               (Name (..))
import           LLVM.General.AST.Operand            (MetadataNode (..),
                                                      Operand (..))
import           LLVM.General.AST.ParameterAttribute (ParameterAttribute (..))
import           LLVM.General.AST.Type               (Type (..), double, i1,
                                                      i32, i64, i8, ptr)
import qualified LLVM.General.AST.Type               as LLVM (Type)
import           LLVM.General.AST.Visibility         (Visibility (Default))
import           Prelude                             hiding (Ordering (EQ))
--------------------------------------------------------------------------------

{- Given the instruction block of the main program, construct the main LLVM function-}
mainDefinition :: G.Instruction -> [String] -> LLVM ()
mainDefinition block files = do
  main <- newLabel "main"

  (main #)
  mapM_ openFile files

  addInstruction $ Do Call
    { tailCallKind       = Nothing
    , callingConvention  = CC.C
    , returnAttributes   = []
    , function           = callable voidType initTrashCollectorString
    , arguments          = []
    , functionAttributes = []
    , metadata           = [] }

  addInstruction $ Do Call
    { tailCallKind       = Nothing
    , callingConvention  = CC.C
    , returnAttributes   = []
    , function           = callable voidType openScopeString
    , arguments          = []
    , functionAttributes = []
    , metadata           = [] }

  instruction block

  addInstruction $ Do Call
    { tailCallKind       = Nothing
    , callingConvention  = CC.C
    , returnAttributes   = []
    , function           = callable voidType freeTrashCollectorString
    , arguments          = []
    , functionAttributes = []
    , metadata           = [] }

  mapM_ closeFile files
  pending <- use pendingInsts
  addInstructions pending
  terminate $ Ret (Just . ConstantOperand $ C.Int 32 0) []

  blocks' <- use blocks
  blocks .= Seq.empty
  pendingInsts .= Seq.empty
  addDefinition $ LLVM.GlobalDefinition functionDefaults
    { name        = Name "main"
    , parameters  = ([], False)
    , returnType  = i32
    , basicBlocks = toList blocks'
    }

  where
    openFile file = do
      let
        fileRef = ConstantOperand . C.GlobalReference pointerType . Name $
                  "__" <> file

      fileLabel <- newLabel "file"
      strs <- use stringIds
      let Just i = (pack file) `Map.lookup` strs
      string <- (!i) <$> use stringOps
      addInstruction $ fileLabel := Call
        { tailCallKind       = Nothing
        , callingConvention  = CC.C
        , returnAttributes   = []
        , function           = callable pointerType openFileStr
        , arguments          = [(string,[])]
        , functionAttributes = []
        , metadata           = [] }

      addInstruction $ Do Store
          { volatile = False
          , address  = fileRef
          , value    = LocalReference pointerType fileLabel
          , maybeAtomicity = Nothing
          , alignment = 4
          , metadata  = [] }

    closeFile file = do
      let
        fileRef = ConstantOperand . C.GlobalReference pointerType . Name $
                  "__" <> file
      filePtr <- newLabel "filePtr"
      addInstruction $ filePtr := Load
        { volatile  = False
        , address   = fileRef
        , maybeAtomicity = Nothing
        , alignment = 4
        , metadata  = [] }

      addInstruction $ Do Call
        { tailCallKind       = Nothing
        , callingConvention  = CC.C
        , returnAttributes   = []
        , function           = callable voidType closeFileStr
        , arguments          = [(LocalReference pointerType filePtr,[])]
        , functionAttributes = []
        , metadata           = [] }



{- Translate a definition from Graciela AST to LLVM AST -}
definition :: Definition -> LLVM ()
definition
  Definition { defName, def', pre, post, bound, defLoc = Location (pos, _to) }
  = case def' of
    FunctionDef { funcBody, funcRetType, funcParams, funcRecursive } -> do
      func <- newLabel $ "func" <> unpack defName
      (func #)

      openScope

      params <- mapM makeParam' . toList $ funcParams
      mapM_ arrAux' funcParams

      preOperand <- precondition pre

      params' <- recursiveParams funcRecursive

      returnOperand <- expression' funcBody
      returnVar     <- insertVar defName
      returnType    <- toLLVMType funcRetType

      addInstruction $ returnVar := Alloca
        { allocatedType = returnType
        , numElements   = Nothing
        , alignment     = 4
        , metadata      = [] }

      addInstruction $ Do Store
        { volatile = False
        , address  = LocalReference returnType returnVar
        , value    = returnOperand
        , maybeAtomicity = Nothing
        , alignment = 4
        , metadata  = [] }

      postcondition preOperand post

      pending <- use pendingInsts
      addInstructions pending

      terminate Ret
        { returnOperand = Just returnOperand
        , metadata' = [] }

      postFix <- do
        cs <- use currentStruct
        case cs of
          Nothing -> pure ""
          Just Struct { structBaseName, structTypes } ->
            llvmName ("-" <> structBaseName) <$> mapM toLLVMType structTypes

      let name = Name $ unpack defName <> postFix
      blocks' <- use blocks
      blocks .= Seq.empty
      pendingInsts .= Seq.empty

      addDefinition $ LLVM.GlobalDefinition functionDefaults
        { name        = name
        , parameters  = (params' <> params, False)
        , returnType
        , basicBlocks = toList blocks'
        }
      closeScope


    ProcedureDef { procDecl, procParams, procBody, procRecursive } -> do
      proc <- newLabel $ "proc" <> unpack defName
      (proc #)

      openScope

      params <- mapM makeParam . toList $ procParams
      mapM_ declarationsOrRead procDecl

      mapM_ arrAux procParams
      cond <- precondition pre

      params' <- recursiveParams procRecursive

      cs <- use currentStruct
      pName <- case cs of
        Nothing -> do
          instruction procBody
          postcondition cond post
          blocks' <- use blocks
          pure $ unpack defName

        Just Struct{ structBaseName, structTypes, struct' = DataType{abstract} } -> do
          let
            dts = filter getDTs . toList $ procParams

          postFix <- llvmName ("-" <> structBaseName) <$> mapM toLLVMType structTypes
          abstractStruct <- (Map.lookup abstract) <$> use structs

          let
            maybeProc = case abstractStruct of
              Just Struct {structProcs} -> defName `Map.lookup` structProcs
              Nothing -> error "Internal error: Missing Abstract Data Type."

          mapM_ (callCouple    ("couple" <> postFix)) dts
          case maybeProc of
            Just Definition{ pre = pre', def' = AbstractProcedureDef{ abstPDecl }} -> do
              mapM_ declaration abstPDecl
              preconditionAbstract cond pre'
            _ -> pure ()
          mapM_ (callInvariant ("inv"     <> postFix) cond) dts
          mapM_ (callInvariant ("coupInv" <> postFix) cond) dts
          mapM_ (callInvariant ("repInv"  <> postFix) cond) dts

          instruction procBody

          mapM_ (callCouple    ("couple"  <> postFix)     ) dts
          mapM_ (callInvariant ("inv"     <> postFix) cond) dts
          mapM_ (callInvariant ("coupInv" <> postFix) cond) dts
          mapM_ (callInvariant ("repInv"  <> postFix) cond) dts
          case maybeProc of
            Just Definition{post = post'} -> postconditionAbstract cond post'
            _                             -> pure ()
          postcondition cond post


          pending <- use pendingInsts
          addInstructions pending

          pure $ unpack defName <> postFix

      terminate $ Ret Nothing []

      blocks' <- use blocks

      addDefinition $ LLVM.GlobalDefinition functionDefaults
        { name        = Name pName
        , parameters  = (params' <> params,False)
        , returnType  = voidType
        , basicBlocks = toList blocks'
        }

      blocks .= Seq.empty
      pendingInsts .= Seq.empty
      closeScope

    GracielaFunc {} -> pure ()

  where
    makeParam' (name, t) = makeParam (name, t, T.In)

    makeParam (name, t, mode) = do
      substTable <- use substitutionTable
      let
        t' = if null substTable
              then t
              else T.fillType (head substTable) t

      if t' =:= T.GOneOf [T.GBool, T.GChar, T.GInt, T.GFloat] && mode == T.In
        then do
          name' <- insertVar name
          t'    <- toLLVMType t
          pure $ Parameter t' name' []
        else do
          name' <- insertVar name
          t'    <- toLLVMType t
          pure $ Parameter (ptr t') name' []

    arrAux' (arr, t) = arrAux (arr, t, T.In)

    arrAux (arr, t@(T.GArray dims inner), mode) = do
      t' <- toLLVMType t
      arrName <- getVariableName arr
      void $ foldM (dimAux t' arrName) 0 dims
      where
        dimAux t' arrName n dim = do
          paramDim <- expression dim

          dimAddr <- newUnLabel
          addInstruction $ dimAddr := GetElementPtr
            { inBounds = False
            , address  = LocalReference t' arrName
            , indices  =
              [ ConstantOperand (C.Int 32 0)
              , ConstantOperand (C.Int 32 n) ]
            , metadata = [] }

          argDim <- newLabel "arrCheck"
          addInstruction $ argDim := Load
            { volatile       = False
            , address        = LocalReference i32 dimAddr
            , maybeAtomicity = Nothing
            , alignment      = 4
            , metadata       = [] }

          arrCheckCmp <- newLabel "arrCheckCmp"
          addInstruction $ arrCheckCmp := ICmp
            { iPredicate = EQ
            , operand0 = paramDim
            , operand1 = LocalReference i32 argDim
            , metadata = [] }

          arrOk <- newLabel "arrOk"
          arrNotOk <- newLabel "arrNotOk"
          terminate CondBr
            { condition = LocalReference i1 arrCheckCmp
            , trueDest  = arrOk
            , falseDest = arrNotOk
            , metadata' = [] }

          (arrNotOk #)
          abort Abort.BadArrayArg (L.pos . loc $ dim)

          (arrOk #)
          pure $ n + 1

    arrAux _ = pure ()

    callCouple funName (name, t, _) = do
      type' <- toLLVMType t
      name' <- getVariableName name

      addInstruction $ Do Call
        { tailCallKind       = Nothing
        , callingConvention  = CC.C
        , returnAttributes   = []
        , function           = callable voidType funName
        , arguments          = [(LocalReference type' name',[])]
        , functionAttributes = []
        , metadata           = [] }

    callInvariant funName cond (name, t, _) = do

      type' <- toLLVMType t
      name' <- getVariableName name

      addInstruction $ Do Call
        { tailCallKind       = Nothing
        , callingConvention  = CC.C
        , returnAttributes   = []
        , function           = callable voidType funName
        , arguments          = [(LocalReference type' name',[]), (cond,[])]
        , functionAttributes = []
        , metadata           = [] }

    getDTs (_, t, _) = case t of
      T.GDataType {} -> True
      _              -> False

    recursiveParams isRecursive = if isRecursive
      then do
        let
          boundExp = fromMaybe
            (internal "boundless recursive function.")
            bound
          hasOldBound = Name $ "." <> unpack defName <> "HasOldBound"
          oldBound = Name $ "." <> unpack defName <> "OldBound"

        funcBodyLabel <- newLabel $ "func" <> unpack defName <> "Body"
        boundOperand <- expression boundExp

        gte0 <- newLabel "funcBoundGte0"
        addInstruction $ gte0 := ICmp
          { iPredicate = SGE
          , operand0   = boundOperand
          , operand1   = ConstantOperand $ C.Int 32 0
          , metadata   = [] }
        yesGte0 <- newLabel "funcGte0Yes"
        noGte0  <- newLabel "funcGte0No"
        terminate CondBr
          { condition = LocalReference boolType gte0
          , trueDest  = yesGte0
          , falseDest = noGte0
          , metadata' = [] }

        (noGte0 #)
        abort Abort.NegativeBound
          (let Location (pos, _) = loc boundExp in pos)

        (yesGte0 #)
        yesOld <- newLabel "funcOldBoundYes"
        noOld  <- newLabel "funcOldBoundNo"
        terminate CondBr
          { condition = LocalReference boolType hasOldBound
          , trueDest  = yesOld
          , falseDest = noOld
          , metadata' = [] }

        (noOld #)
        terminate Br
          { dest = funcBodyLabel
          , metadata' = [] }

        (yesOld #)
        ltOld <- newLabel "funcLtOld"
        addInstruction $ ltOld := ICmp
          { iPredicate = SLT
          , operand0   = boundOperand
          , operand1   = LocalReference intType oldBound
          , metadata   = [] }
        yesLtOld <- newLabel "funcLtOldBoundYes"
        noLtOld  <- newLabel "funcLtOldBoundNo"
        terminate CondBr
          { condition = LocalReference boolType ltOld
          , trueDest  = yesLtOld
          , falseDest = noLtOld
          , metadata' = [] }

        (noLtOld #)
        abort Abort.NondecreasingBound
          (let Location (pos, _) = loc boundExp in pos)

        (yesLtOld #)
        terminate Br
          { dest = funcBodyLabel
          , metadata' = [] }

        (funcBodyLabel #)

        boundOp .= Just boundOperand
        pure [Parameter i1 hasOldBound [], Parameter i32 oldBound []]

      else pure []

    declarationsOrRead :: Either Declaration G.Instruction -> LLVM ()
    declarationsOrRead (Left decl)   = declaration decl
    declarationsOrRead (Right read') = instruction read'

    precondition :: Expression -> LLVM Operand
    precondition expr@ Expression {loc = Location (pos,_) } = do
        -- Create both labels
        trueLabel  <- newLabel "precondTrue"
        falseLabel <- newLabel "precondFalse"
        -- Evaluate the condition expression
        cond <- wrapBoolean expr
        -- Add the conditional branch
        terminate CondBr
          { condition = cond
          , trueDest  = trueLabel
          , falseDest = falseLabel
          , metadata' = [] }
        -- Set the false label to the warning, then continue normally
        (falseLabel #)
        warn Warning.Pre pos
        terminate Br
          { dest      = trueLabel
          , metadata' = [] }

        -- And the true label to the next instructions
        (trueLabel #)

        pure cond

    preconditionAbstract :: Operand -> Expression -> LLVM ()
    preconditionAbstract precond expr@ Expression {loc = Location (pos,_) } = do
      -- Create both labels
      evaluate   <- newLabel "evaluate"
      trueLabel  <- newLabel "precondAbstTrue"
      falseLabel <- newLabel "precondAbstFalse"
      -- Evaluate the condition expression
      cond <- wrapBoolean expr

      terminate CondBr
        { condition = precond
        , trueDest  = evaluate
        , falseDest = trueLabel
        , metadata' = [] }

      -- Add the conditional branch
      (evaluate #)
      terminate CondBr
        { condition = cond
        , trueDest  = trueLabel
        , falseDest = falseLabel
        , metadata' = [] }
      -- Set the false label to the warning, then continue normally
      (falseLabel #)
      abort Abort.BadAbstractCouple pos

      -- And the true label to the next instructions
      (trueLabel #)

    postconditionAbstract :: Operand -> Expression -> LLVM ()
    postconditionAbstract precond expr@ Expression {loc = Location (pos,_) } = do
      -- Create both labels
      evaluate   <- newLabel "evaluate"
      trueLabel  <- newLabel "precondAbstTrue"
      falseLabel <- newLabel "precondAbstFalse"

      terminate CondBr
        { condition = precond
        , trueDest  = evaluate
        , falseDest = trueLabel
        , metadata' = [] }


      (evaluate #)
      -- Evaluate the condition expression
      cond <- wrapBoolean expr
      -- Add the conditional branch
      terminate CondBr
        { condition = cond
        , trueDest  = trueLabel
        , falseDest = falseLabel
        , metadata' = [] }
      -- Set the false label to the warning, then continue normally
      (falseLabel #)
      abort Abort.AbstractPost pos

      -- And the true label to the next instructions
      (trueLabel #)

    postcondition :: Operand -> Expression -> LLVM ()
    postcondition precond expr@ Expression {loc = Location(pos,_)} = do
      -- Create both labels
      evaluate   <- newLabel "evaluate"
      trueLabel  <- newLabel "postcondTrue"
      falseLabel <- newLabel "postcondFalse"

      -- Create the conditional branch
      terminate CondBr
        { condition = precond
        , trueDest  = evaluate
        , falseDest = trueLabel
        , metadata' = [] }

      (evaluate #)
      -- Evaluate the condition expression
      cond <- wrapBoolean expr
      -- Add the conditional branch
      terminate CondBr
        { condition = cond
        , trueDest  = trueLabel
        , falseDest = falseLabel
        , metadata' = [] }
      -- Set the false label to the warning, then continue normally
      (falseLabel #)
      abort Abort.Post pos
      -- And the true label to the next instructions

      (trueLabel #)


preDefinitions :: [String] -> LLVM ()
preDefinitions files = do
  mapM_ addFile files
  addDefinitions $ fromList

    [ -- Random
      defineFunction randomInt [] intType



    -- Trace pseudo Functions
    , defineFunction traceIntString         intParam intType
    , defineFunction traceFloatString       floatParam floatType
    , defineFunction traceCharString        charParam charType
    , defineFunction traceBoolString        boolParam boolType
    , defineFunction traceStringIntString   [ parameter ("x", stringType)
                                            , parameter ("y", intType) ]
                                            intType
    , defineFunction traceStringFloatString [ parameter ("x", stringType)
                                            , parameter ("y", floatType) ]
                                            floatType
    , defineFunction traceStringCharString  [ parameter ("x", stringType)
                                            , parameter ("y", charType) ]
                                            charType
    , defineFunction traceStringBoolString  [ parameter ("x", stringType)
                                            , parameter ("y", boolType) ]
                                            boolType

    -- Conversion functions
    , defineFunction float2intString  [ parameter ("x", floatType)
                                      , parameter ("line", intType)
                                      , parameter ("column", intType) ]
                                      intType
    , defineFunction char2intString   charParam intType
    , defineFunction float2charString [ parameter ("x", floatType)
                                      , parameter ("line", intType)
                                      , parameter ("column", intType) ]
                                      charType
    , defineFunction int2charString   [ parameter ("x", intType)
                                      , parameter ("line", intType)
                                      , parameter ("column", intType) ]
                                      charType
    , defineFunction char2floatString charParam floatType
    , defineFunction int2floatString  intParam  floatType

    -- Polymorphic functions
    , defineFunction sqrtIString [ parameter ("x", intType)
                                 , parameter ("line", intType)
                                 , parameter ("column", intType) ]
                                 intType
    , defineFunction sqrtFString [ parameter ("x", floatType)
                                 , parameter ("line", intType)
                                 , parameter ("column", intType)]
                                 floatType
    , defineFunction absIString  [ parameter ("x", intType)
                                 , parameter ("line", intType)
                                 , parameter ("column", intType)]
                                 intType

    , defineFunction absFString               floatParam floatType
    , defineFunction toSetMultiString         ptrParam   pointerType
    , defineFunction toSetSeqString           ptrParam   pointerType
    , defineFunction toSetFuncString          ptrParam   pointerType
    , defineFunction toSetRelString           ptrParam   pointerType
    , defineFunction toMultiSetString         ptrParam   pointerType
    , defineFunction toMultiSeqString         ptrParam   pointerType

--------------------------------------------------------------------------------


    , defineFunction firstSetString           ptrParam (ptr iterator)
    , defineFunction nextSetString            [parameter ("x", (ptr iterator))] 
                                              (ptr iterator) 
    
    , defineFunction firstMultisetString      ptrParam (ptr iterator)
    , defineFunction nextMultisetString       [parameter ("x", (ptr iterator))] 
                                              (ptr iterator) 
    
    , defineFunction firstSequenceString      ptrParam (ptr iterator)
    , defineFunction nextSequenceString       [parameter ("x", (ptr iterator))] 
                                              (ptr iterator) 

    , defineFunction initTrashCollectorString [] voidType
    , defineFunction freeTrashCollectorString [] voidType
    , defineFunction openScopeString          [] voidType

    -- (Bi)Functors
    , defineFunction newSetString             [] pointerType
    , defineFunction newSeqString             [] pointerType
    , defineFunction newMultisetString        [] pointerType

    , defineFunction newSetPairString         [] pointerType
    , defineFunction newMultisetPairString    [] pointerType
    , defineFunction newSeqPairString         [] pointerType

--------------------------------------------------------------------------------

    , defineFunction equalSetString            ptrParam2 boolType
    , defineFunction equalSeqString            ptrParam2 boolType
    , defineFunction equalMultisetString       ptrParam2 boolType

    , defineFunction equalSetPairString        ptrParam2 boolType
    , defineFunction equalSeqPairString        ptrParam2 boolType
    , defineFunction equalMultisetPairString   ptrParam2 boolType

    , defineFunction equalFuncString           ptrParam2 boolType
    , defineFunction equalRelString            ptrParam2 boolType

    , defineFunction equalTupleString            [ parameter ("x", ptr tupleType)
                                               , parameter ("y", ptr tupleType)]
                                               boolType
--------------------------------------------------------------------------------
    , defineFunction sizeSetString             ptrParam intType
    , defineFunction sizeSeqString             ptrParam intType
    , defineFunction sizeMultisetString        ptrParam intType
    , defineFunction sizeRelString             ptrParam intType
    , defineFunction sizeFuncString            ptrParam intType
--------------------------------------------------------------------------------
    , defineFunction supersetSetString         ptrParam2 boolType
    , defineFunction supersetMultisetString    ptrParam2 boolType
    , defineFunction ssupersetSetString        ptrParam2 boolType
    , defineFunction ssupersetMultisetString   ptrParam2 boolType

    , defineFunction supersetSetPairString         ptrParam2 boolType
    , defineFunction supersetMultisetPairString    ptrParam2 boolType
    , defineFunction ssupersetSetPairString        ptrParam2 boolType
    , defineFunction ssupersetMultisetPairString   ptrParam2 boolType
--------------------------------------------------------------------------------
    , defineFunction insertSetString           ptri64Param voidType
    , defineFunction insertSeqString           ptri64Param voidType
    , defineFunction insertMultisetString      ptri64Param voidType

    , defineFunction insertSetPairString       ptrTupleParam voidType
    , defineFunction insertSeqPairString       ptrTupleParam voidType
    , defineFunction insertMultisetPairString  ptrTupleParam voidType
--------------------------------------------------------------------------------

    , defineFunction isElemSetString          ptri64Param boolType
    , defineFunction isElemMultisetString     ptri64Param boolType
    , defineFunction isElemSeqString          ptri64Param boolType

    , defineFunction isElemSetPairString      ptrTupleParam boolType
    , defineFunction isElemMultisetPairString ptrTupleParam boolType
    , defineFunction isElemSeqPairString      ptrTupleParam boolType
--------------------------------------------------------------------------------
    , defineFunction unionSetString           ptrParam2 pointerType
    , defineFunction intersectSetString       ptrParam2 pointerType
    , defineFunction differenceSetString      ptrParam2 pointerType

    , defineFunction unionSetPairString       ptrParam2 pointerType
    , defineFunction intersectSetPairString   ptrParam2 pointerType
    , defineFunction differenceSetPairString  ptrParam2 pointerType

    , defineFunction unionMultisetString      ptrParam2 pointerType
    , defineFunction intersectMultisetString  ptrParam2 pointerType
    , defineFunction differenceMultisetString ptrParam2 pointerType

    , defineFunction unionMultisetPairString      ptrParam2 pointerType
    , defineFunction intersectMultisetPairString  ptrParam2 pointerType
    , defineFunction differenceMultisetPairString ptrParam2 pointerType

    , defineFunction unionFunctionString      [ parameter ("x", pointerType)
                                              , parameter ("y", pointerType)
                                              , parameter ("line", intType)
                                              , parameter ("column", intType)]
                                              pointerType
    , defineFunction intersectFunctionString  ptrParam2 pointerType
    , defineFunction differenceFunctionString ptrParam2 pointerType

--------------------------------------------------------------------------------
    , defineFunction multisetSumString            ptrParam2 pointerType
    , defineFunction concatSequenceString         ptrParam2 pointerType

    , defineFunction multiplicityMultiString      [ parameter ("x", i64)
                                                  , parameter ("y", pointerType)]
                                                  intType
    , defineFunction multiplicitySeqString        [ parameter ("x", i64)
                                                  , parameter ("y", pointerType)]
                                                  intType

    , defineFunction multisetPairSumString        ptrParam2 pointerType
    , defineFunction concatSequencePairString     ptrParam2 pointerType

    , defineFunction multiplicityMultiPairString  [ parameter ("x", ptr tupleType)
                                                  , parameter ("y", pointerType)]
                                                  intType

    , defineFunction multiplicitySeqPairString    [ parameter ("x", ptr tupleType)
                                                  , parameter ("y", pointerType)]
                                                  intType

    , defineFunction atSequenceString             [ parameter ("x", pointerType)
                                                  , parameter ("y", intType)
                                                  , parameter ("line", intType)
                                                  , parameter ("column", intType)]
                                                  i64
    , defineFunction atSequencePairString         [ parameter ("x", pointerType)
                                                  , parameter ("y", intType)
                                                  , parameter ("line", intType)
                                                  , parameter ("column", intType)]
                                                  tupleType

--------------------------------------------------------------------------------
    , defineFunction relString                ptrParam   pointerType
    , defineFunction funcString               [ parameter ("x", pointerType)
                                              , parameter ("line", intType)
                                              , parameter ("column", intType)]
                                              pointerType

    , defineFunction domainFuncString         ptrParam    pointerType
    , defineFunction domainRelString          ptrParam    pointerType

    , defineFunction codomainFuncString       ptrParam    pointerType
    , defineFunction codomainRelString        ptrParam    pointerType

    , defineFunction evalFuncString           [ parameter ("x", pointerType)
                                              , parameter ("y", i64)
                                              , parameter ("line", intType)
                                              , parameter ("column", intType)]  i64
    , defineFunction evalRelString            ptri64Param pointerType

    , defineFunction inverseFuncString        ptrParam    pointerType
    , defineFunction inverseRelString         ptrParam    pointerType


--------------------------------------------------------------------------------
    -- Abort
    , defineFunction abortString [ parameter ("x", intType)
                                 , parameter ("line", intType)
                                 , parameter ("column", intType)]
                                 voidType
    , defineFunction warnString [ parameter ("x", intType)
                                , parameter ("line", intType)
                                , parameter ("column", intType)]
                                voidType
    -- Min and max
    , defineFunction minnumString intParams2 intType
    , defineFunction maxnumString intParams2 intType

    -- Line feed
    , defineFunction lnString [] voidType

    -- Bool Write
    , defineFunction writeBString boolParam voidType

    -- Char Write
    , defineFunction writeCString charParam voidType

    -- Float Write
    , defineFunction writeFString floatParam voidType

    -- Int Write
    , defineFunction writeIString intParam voidType

    -- String Write
    , defineFunction writeSString stringParam voidType

    -- Square Root and absolute value
    , defineFunction sqrtString    floatParam floatType
    , defineFunction fabsString    floatParam floatType

    , defineFunction minnumFstring  floatParams2 floatType
    , defineFunction maxnumFstring  floatParams2 floatType
    , defineFunction powIString     [ parameter ("x", intType)
                                    , parameter ("y", intType)
                                    , parameter ("line", intType)
                                    , parameter ("column", intType)]
                                    intType
    , defineFunction powString      floatParams2 floatType


    , defineFunction (safeSub 32) intParams2 (overflow' 32)
    , defineFunction (safeMul 32) intParams2 (overflow' 32)
    , defineFunction (safeAdd 32) intParams2 (overflow' 32)

    , defineFunction (safeSub 8) charParams2 (overflow' 8)
    , defineFunction (safeMul 8) charParams2 (overflow' 8)
    , defineFunction (safeAdd 8) charParams2 (overflow' 8)

    -- Read
    , defineFunction readIntStd    [] intType
    , defineFunction readBoolStd   [] boolType
    , defineFunction readCharStd   [] charType
    , defineFunction readFloatStd  [] floatType

    -- Malloc
    , defineFunction mallocString intParam pointerType
    , defineFunction freeString [parameter ("x", pointerType)] voidType


    , defineFunction readFileInt   [parameter ("file", pointerType)] intType
    , defineFunction readFileBool  [parameter ("file", pointerType)] boolType
    , defineFunction readFileChar  [parameter ("file", pointerType)] charType
    , defineFunction readFileFloat [parameter ("file", pointerType)] floatType
    , defineFunction closeFileStr  [parameter ("file", pointerType)] voidType
    , defineFunction openFileStr   [parameter ("name", pointerType)] pointerType
    ]

  where
    defineFunction name params t = LLVM.GlobalDefinition $ functionDefaults
      { name        = Name name
      , parameters  = (params, False)
      , returnType  = t
      , basicBlocks = [] }
    parameter (name, t) = Parameter t (Name name) []
    intParam      = [parameter ("x",     intType)]
    charParam     = [parameter ("x",    charType)]
    boolParam     = [parameter ("x",    boolType)]
    floatParam    = [parameter ("x",   floatType)]
    ptrParam      = [parameter ("x", pointerType)]
    ptrParam2     = [parameter ("x", pointerType), parameter ("y", pointerType)]
    ptri64Param   = [parameter ("x", pointerType), parameter ("y", i64)]
    ptrTupleParam = [parameter ("x", pointerType), parameter ("y", ptr tupleType)]
    intParams2    = fmap parameter [("x",   intType), ("y",   intType)]
    charParams2   = fmap parameter [("x",  charType), ("y",  charType)]
    floatParams2  = fmap parameter [("x", floatType), ("y", floatType)]
    stringParam   = [Parameter stringType (Name "msg") [NoCapture]]
    overflow' n   = StructureType False [IntegerType n, boolType]
    addFile file  = addDefinition $ LLVM.GlobalDefinition GlobalVariable
        { name            = Name ("__" <> file)
        , linkage         = Private
        , visibility      = Default
        , dllStorageClass = Nothing
        , threadLocalMode = Nothing
        , addrSpace       = AddrSpace 0
        , hasUnnamedAddr  = False
        , isConstant      = False
        , type'           = pointerType
        , initializer     = Just . C.Null $ pointerType
        , section         = Nothing
        , comdat          = Nothing
        , alignment       = 4
      }