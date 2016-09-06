{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module LLVM.Monad where
--------------------------------------------------------------------------------
import           LLVM.State                   hiding (State)
import qualified LLVM.State                   as LLVM (State)
--------------------------------------------------------------------------------
import           Control.Lens                 (use, (%=), (.=), (<<+=))
import           Control.Monad.State          (MonadState, State)
import           Data.Foldable                (toList)
import qualified Data.Map                     as Map (insert, lookup)
import           Data.Monoid                  ((<>))
import           Data.Sequence                (Seq, (|>))
import qualified Data.Sequence                as Seq
import           LLVM.General.AST             (BasicBlock (..))
import qualified LLVM.General.AST             as LLVM (Definition (..))
import           LLVM.General.AST.Constant    (Constant (GlobalReference))
import           LLVM.General.AST.Instruction (Named (..), Terminator (..))
import qualified LLVM.General.AST.Instruction as LLVM (Instruction (..))
import           LLVM.General.AST.Name        (Name (..))
import           LLVM.General.AST.Operand     (Operand (ConstantOperand))
import           LLVM.General.AST.Type        (Type)
--------------------------------------------------------------------------------

type Inst  = Named LLVM.Instruction
type Insts = Seq Inst

newtype LLVM a = LLVM { unLLVM :: State LLVM.State a }
  deriving (Functor, Applicative, Monad, MonadState LLVM.State)
--------------------------------------------------------------------------------

addDefinitions :: Seq LLVM.Definition -> LLVM ()
addDefinitions defs =
  moduleDefs %= (<> defs)

addDefinition :: LLVM.Definition -> LLVM ()
addDefinition defs =
  moduleDefs %= (|> defs)

addInstructions :: Insts -> LLVM ()
addInstructions insts =
  currentBlock %= (<> insts)

addInstruction :: Inst -> LLVM ()
addInstruction inst =
  currentBlock %= (|> inst)
--------------------------------------------------------------------------------

terminate :: Named Terminator -> LLVM ()
terminate terminator = do
  name' <- use blockName
  case name' of
    Nothing -> error $
      "internal error: attempted to terminate an unnamed block with\n" <>
      show terminator <> "\n"
    Just name -> do
      insts <- use currentBlock
      blocks %= (|> BasicBlock name (toList insts) terminator)
      currentBlock .= Seq.empty
      blockName .= Nothing

terminate' :: Terminator -> LLVM ()
terminate' = terminate . Do

(#) :: Name -> LLVM ()
(#) name = do
  old <- use blockName
  case old of
    Nothing -> blockName .= Just name
    Just oldName  -> error $
      "internal error: attempted to rename current bloc, " <> show oldName <>
      " as " <> show name <> "."
--------------------------------------------------------------------------------

newLabel :: String -> LLVM Name
newLabel label = do
  ns <- use nameSupply
  case label `Map.lookup` ns of
    Nothing -> do
      nameSupply %= Map.insert label 1
      pure . Name $ label <> "$" <> show 0
    Just i  -> do
      nameSupply %= Map.insert label (succ i)
      pure . Name $ label <> "#" <> show i

newUnLabel :: LLVM Name
newUnLabel = newLabel ""
--------------------------------------------------------------------------------

callable :: Type -> String -> Either a Operand
callable t = Right . ConstantOperand . GlobalReference t . Name

freeString    :: String
freeString    = "_free"
mallocString  :: String
mallocString  = "_malloc"
lnString      :: String
lnString      = "_ln"
writeIString  :: String
writeIString  = "_writeInt"
writeBString  :: String
writeBString  = "_writeBool"
writeCString  :: String
writeCString  = "_writeChar"
writeFString  :: String
writeFString  = "_writeDouble"
writeSString  :: String
writeSString  = "_writeString"
randomInt     :: String
randomInt     = "_random"
sqrtString    :: String
sqrtString    = "llvm.sqrt.f64"
fabsString    :: String
fabsString    = "llvm.fabs.f64"
powString     :: String
powString     = "llvm.pow.f64"
minnumString  :: String
minnumString  = "_min"
maxnumString  :: String
maxnumString  = "_max"
minnumFstring :: String
minnumFstring = "_minF"
maxnumFstring :: String
maxnumFstring = "_maxF"
readIntStd    :: String
readIntStd    = "_readIntStd"
readCharStd   :: String
readCharStd   = "_readCharStd"
readFloatStd  :: String
readFloatStd  = "_readDoubleStd"
openFileStr   :: String
openFileStr   = "_openFile"
readFileInt   :: String
readFileInt   = "_readFileInt"
closeFileStr  :: String
closeFileStr  = "_closeFile"
readFileChar  :: String
readFileChar  = "_readFileChar"
readFileFloat :: String
readFileFloat = "_readFileDouble"
intAdd        :: String
intAdd        = "llvm.sadd.with.overflow.i32"
intSub        :: String
intSub        = "llvm.ssub.with.overflow.i32"
intMul        :: String
intMul        = "llvm.smul.with.overflow.i32"