module Parser.State where
-- --------------------------------------------------------------------------------
-- -- import           Parser.TokenParser
-- import           AST                    hiding (Constant)
-- import           Data.Maybe
-- import           Entry
-- import           Graciela
-- import           MyParseError
-- import           ParserError
-- import           SourcePos
-- import           SymbolTable
-- import           Token
-- import           Type
-- import           TypeError
-- --------------------------------------------------------------------------------
-- import           Control.Lens           (use, (%=), (.=), (<%=))
-- import           Control.Monad.Identity (Identity)
-- import           Control.Monad.State    (StateT, get, modify)
-- import           Data.Foldable          (toList)
-- import           Data.Function          (on)
-- import           Data.Sequence          (Seq, (|>))
-- import qualified Data.Sequence          as Seq (empty, null, sortBy)
-- import qualified Data.Set               as Set (Set, empty, insert)
-- import           Data.Text              (Text)
-- import           Prelude                hiding (lookup)
-- import           Text.Megaparsec
-- --------------------------------------------------------------------------------
--
-- addFileToReadParser :: String -> Graciela ()
-- addFileToReadParser file = filesToRead %= Set.insert file
--
--
-- addFunTypeParser :: Text
--                  -> Maybe [(Text, Type)]
--                  -> Type
--                  -> SourcePos
--                  -> SymbolTable
--                  -> Graciela ()
-- addFunTypeParser id (Just lt) t pos sb =
--     addSymbolParser id (Function id pos (GFunction snds t) fsts sb)
--     where
--         (fsts, snds) = unzip lt
--
-- addFunTypeParser _ _ _ _ _ = return ()
--
--
-- addProcTypeParser :: Text
--                   -> Maybe [(Text, Type)]
--                   -> SourcePos
--                   -> SymbolTable -> Graciela ()
-- addProcTypeParser id (Just xs) pos sb =
--     addSymbolParser id $ Procedure id pos (GProcedure snds) fsts sb
--     where (fsts, snds) = unzip xs
-- addProcTypeParser _ _ _ _             = return ()
--
--
-- getCurrentScope :: Graciela SymbolTable
-- getCurrentScope = use symbolTable
--
--
-- newScopeParser :: Graciela ()
-- newScopeParser = do
--   p <- getPosition
--   symbolTable %= openScope p
--
--
-- getScopeParser :: Graciela Int
-- getScopeParser = do
--   st <- use symbolTable
--   return $ depth st
--
--
-- exitScopeParser :: Graciela ()
-- exitScopeParser = do
--   p <- getPosition
--   st <- symbolTable <%= closeScope p
--
--   case st  of
--     Left _     -> synErrorList %= (|> ScopesError)
--     Right sbtl -> pure ()
--
--
--
-- addManyUniSymParser :: Maybe [(Text, SourcePos)] -> Type -> Graciela ()
-- addManyUniSymParser (Just xs) t = f xs t
--     where
--         f ((id, pos):xs) t = do
--             addSymbolParser id $ Entry id pos pos $ Variable t Nothing
--             f xs t
--         f [] _ = return ()
--
-- addManyUniSymParser _ _ = return ()
--
--
-- addManySymParser :: Maybe [(Text , SourcePos)]
--                  -> Type
--                  -> Maybe [AST]
--                  -> Graciela ()
-- -- addManySymParser (Just xs) t (Just ys) =
-- --     if length xs /= length ys then
-- --         do pos <- getPosition
-- --            sTableErrorList %= (|> IncomDefError pos)
-- --     else f xs t ys
-- --       where
-- --         f ((id, pos):xs) t (ast:ys) =
-- --             do addSymbolParser id $ Contents id pos t (astToValue ast) True
-- --                f xs t ys
-- --         f _ [] _ []                    = return ()
--
-- addManySymParser _ _ _               = return ()
--
--
-- -- astToValue AST { ast' = (Int    n) } = Just $ I n
-- -- astToValue AST { ast' = (Float  f) } = Just $ D f
-- -- astToValue AST { ast' = (Bool   b) } = Just $ B b
-- -- astToValue AST { ast' = (Char   c) } = Just $ C c
-- -- astToValue AST { ast' = (String s) } = Just $ S s
-- -- astToValue _                         = Nothing
--
--
-- -- verifyReadVars :: Maybe [(Text, SourcePos)] -> Graciela [Type]
-- -- verifyReadVars (Just lid) = catMaybes <$> mapM (lookUpConsParser . fst) lid
-- -- verifyReadVars _          = return []
--
--
-- addFunctionArgParser :: Text -> Text -> Type -> SourcePos -> Graciela ()
-- addFunctionArgParser idf id t pos =
--   if id /= idf
--     then addSymbolParser id $ Entry id pos pos $ Variable t Nothing
--     else typeError $ FunctionNameError id pos
--
--
-- addArgProcParser :: Text -> Text
--                  -> Type -> SourcePos
--                  -> Maybe ArgMode -> Graciela ()
-- addArgProcParser id pid t pos (Just targ) =
--     if id /= pid then
--       addSymbolParser id $ Entry id pos pos $ Argument targ t
--     else
--       typeError $ FunctionNameError id pos
-- addArgProcParser _ _ _ _ _ = return ()
--
--
-- addSymbolParser :: Text -> Entry -> Graciela ()
-- addSymbolParser symbol content = do
--   st <- use symbolTable
--
--   case local symbol st of
--     Right con -> sTableErrorList %=
--       (|> (RepSymbolError symbol `on` _posFrom) con content)
--     Left _ -> symbolTable %= insertSymbol symbol content
--
--
--
-- addCuantVar :: QuantOp -> Text -> Type -> SourcePos -> Graciela ()
-- addCuantVar op id t pos =
--   if isQuantifiable t then
--    addSymbolParser id $ Entry id pos pos $ Variable t Nothing True
--   else
--    typeError $ UncountableError op pos
--
--
-- lookUpSymbol :: Text -> Graciela (Either Text Entry)
-- lookUpSymbol sym =
--   use symbolTable >>= lookup sym
--
--
--
-- -- lookUpVarParser :: Text -> SourcePos -> Graciela (Maybe Type)
-- -- lookUpVarParser id pos = do
-- --     st <- use symbolTable
-- --     c  <- lookUpSymbol id
-- --     case c of
-- --         Just content -> return $ fmap getContentType c
-- --         _ -> return Nothing
-- --
-- --
-- --
-- -- lookUpConsParser :: Text -> Graciela (Maybe Type)
-- -- lookUpConsParser id = do
-- --     symbol <- lookUpSymbol id
-- --     case symbol of
-- --         Just content ->
-- --             if isLValue content then do
-- --                 symbolTable %= initSymbol id
-- --                 return $ Just $ getContentType content
-- --             else do
-- --                 addConsIdError id
-- --                 return Nothing
-- --         _   -> return Nothing
--
--
-- -- lookUpConstIntParser :: Text -> SourcePos -> Graciela (Maybe Type)
-- -- lookUpConstIntParser id pos = do
-- --     symbol <- lookUpSymbol id
-- --     pos <- getPosition
-- --     case symbol of
-- --         Nothing -> return Nothing
-- --         Just content  ->
-- --             if isInitialized content then
-- --                 if isRValue content then
-- --                     if getContentType content == GInt then
-- --                         return $ return GInt
-- --                     else do
-- --                         typeError $ NotIntError id pos
-- --                         return Nothing
-- --                 else do
-- --                     typeError $ NotRValueError id pos
-- --                     return Nothing
-- --             else do
-- --                 typeError $ NotInitError id pos
-- --                 return Nothing
--
--
-- addConsIdError :: Text -> Graciela ()
-- addConsIdError id = do
--     pos <- getPosition
--     sTableErrorList %= (|> ConstIdError id pos)
--
--
-- addNonDeclVarError :: Text -> Graciela ()
-- addNonDeclVarError id = do
--     pos <- getPosition
--     sTableErrorList %= (|> ConstIdError id pos)
--
--
-- addNonAsocError :: Graciela ()
-- addNonAsocError = do
--     pos <- getPosition
--     synErrorList %= (|> NonAsocError pos)
--
--
-- addArrayCallError :: Int -> Int -> Graciela ()
-- addArrayCallError waDim prDim = do
--     pos <- getPosition
--     synErrorList %= (|> ArrayError waDim prDim pos)
--
--
-- -- genNewError :: Graciela Token -> ExpectedToken -> Graciela ()
-- -- genNewError laset msg = do
-- --     pos <- cleanEntry laset
-- --     synErrorList %= (|> newParseError msg pos)
--
--
-- genCustomError :: String -> Graciela ()
-- genCustomError msg = do
--     pos <- getPosition
--     synErrorList %= (|> CustomError msg pos)
--
--
-- genNewEmptyError :: Graciela ()
-- genNewEmptyError = do
--     pos <- getPosition
--     synErrorList %= (|> EmptyError pos)