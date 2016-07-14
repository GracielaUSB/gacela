{-# LANGUAGE TemplateHaskell #-}

module Graciela where
--------------------------------------------------------------------------------
import           Contents
import           Data.Monoid
import           Location
import           MyParseError           as P
import           MyTypeError            as T
import           SymbolTable
import           Text.Parsec
import           Token

--------------------------------------------------------------------------------
import           Control.Lens                   (makeLenses)
import           Control.Monad.Identity (Identity)
import           Control.Monad.State    (StateT)
import           Data.Foldable          (toList)
import           Data.Function          (on)
import           Data.Sequence          (Seq, (|>))
import qualified Data.Sequence          as Seq (empty, null, sortBy)
import qualified Data.Set               as Set (Set, empty, insert)
import           Data.Text              (Text)
--------------------------------------------------------------------------------


type Graciela a = ParsecT [TokenPos] () (StateT GracielaState Identity) a

data GracielaState = GracielaState
    { _synErrorList    :: Seq MyParseError
    , _symbolTable     :: SymbolTable
    , _sTableErrorList :: Seq MyTypeError
    , _filesToRead     :: Set.Set String
    }
    deriving(Show)

makeLenses ''GracielaState

initialState :: GracielaState
initialState = GracielaState
    { _synErrorList    = Seq.empty
    , _symbolTable     = emptyTable
    , _sTableErrorList = Seq.empty
    , _filesToRead     = Set.empty
    }


-- addFileToRead :: String -> GracielaState -> GracielaState
-- addFileToRead file ps =
--     ps { filesToRead = Set.insert file $ filesToRead ps }


-- addTypeError :: MyTypeError -> GracielaState -> GracielaState
-- addTypeError err ps =
--     ps { sTableErrorList = sTableErrorList ps |> err }


-- addParsingError :: MyParseError -> GracielaState -> GracielaState
-- addParsingError e ps =
--     ps { synErrorList = synErrorList ps |> e }


-- addNewSymbol :: Text -> Contents SymbolTable -> GracielaState -> GracielaState
-- addNewSymbol sym c ps = case addSymbol sym c (symbolTable ps) of
--     Left con ->
--         ps { sTableErrorList =
--             sTableErrorList ps |> (RepSymbolError sym `on` symbolLoc) con c }
--     Right sb ->
--         ps { symbolTable = sb }


-- initVar :: Text -> GracielaState -> GracielaState
-- initVar sym ps = ps { symbolTable = initSymbol sym (symbolTable ps) }


-- newScopeState :: GracielaState -> GracielaState
-- newScopeState st = st { symbolTable = enterScope (symbolTable st) }


-- exitScopeState :: GracielaState -> GracielaState
-- exitScopeState st = case exitScope (symbolTable st) of
--     Just sbtl -> st { symbolTable = sbtl }
--     Nothing   -> addParsingError ScopesError st


-- getScopeState :: GracielaState -> Int
-- getScopeState st = getScope $ symbolTable st


-- lookUpVarState :: Text -> SymbolTable -> Maybe (Contents SymbolTable)
-- lookUpVarState = checkSymbol


-- drawState :: Maybe Int -> GracielaState -> String
-- drawState n st = do  
--     errorList <- use synErrorList
--     tableErrorList <- use sTableErrorList
--     if Seq.null $ errorList
--     then if Seq.null $ tableErrorList
--         then "\n HUBO UN ERROR PERO LAS LISTAS ESTAN VACIAS... \n"
--         else drawError . take' n . Seq.sortBy (compare `on` T.loc) . tableErrorList
--     else drawError . take' n . Seq.sortBy (compare `on` P.loc) . errorList


drawState :: Maybe Int -> GracielaState -> String
drawState n st = if Seq.null $ _synErrorList st
    then if Seq.null $ _sTableErrorList st
        then "\n HUBO UN ERROR PERO LAS LISTAS ESTAN VACIAS... \n"
        else drawError . take' n . Seq.sortBy (compare `on` T.loc) . _sTableErrorList $ st
    else drawError . take' n . Seq.sortBy (compare `on` P.loc) . _synErrorList $ st


drawError list = if Seq.null list
    then "LISTA DE ERRORES VACIA"
    else unlines . map show . toList $ list