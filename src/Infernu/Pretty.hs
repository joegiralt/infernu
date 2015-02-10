{-# LANGUAGE FlexibleInstances #-}
module Infernu.Pretty where

import           Infernu.Fix     (fixToList)
import           Infernu.Types

    
import           Data.Char       (chr, ord)
import qualified Data.Char       as Char
import qualified Data.Digits     as Digits
import           Data.List       (intercalate)
import qualified Data.Map.Lazy   as Map
import           Data.Maybe      (catMaybes)
import qualified Data.Set        as Set
import qualified Text.Parsec.Pos as Pos

tab :: Int -> String
tab t = replicate (t*4) ' '

class Pretty a where
  prettyTab :: Int -> a -> String

instance Pretty a => Pretty (Maybe a) where
  prettyTab _ x = maybe "Nothing" pretty x

instance (Pretty a, Pretty b) => Pretty (a,b) where
  prettyTab _ (a,b) = "(" ++ pretty a ++ ", " ++ pretty b ++ ")"

instance (Pretty a, Pretty b, Pretty c) => Pretty (a,b,c) where
  prettyTab _ (a,b,c) = "(" ++ pretty a ++ ", " ++ pretty b ++ ", " ++ pretty c ++ ")"

prettyList :: Pretty a => [a] -> String
prettyList [] = "[]"
prettyList xs = "[" ++ intercalate "," (map pretty xs) ++ "]"

instance Pretty [String] where
  prettyTab _ = prettyList

instance Pretty [Type] where
  prettyTab _  = prettyList

instance (Pretty a, Pretty b) => Pretty [(a,b)] where
  prettyTab _ xs = "[" ++ intercalate "," (map pretty xs) ++ "]"

pretty :: Pretty a => a -> String
pretty = prettyTab 0

instance Pretty LitVal where
  prettyTab _ (LitNumber x) = show x
  prettyTab _ (LitBoolean x) = show x
  prettyTab _ (LitString x) = show x
  prettyTab _ (LitRegex x g i) = "/" ++ x ++ "/" ++ (if g then "g" else "") ++ (if i then "i" else "") ++ (if g || i then "/" else "")
  prettyTab _ LitUndefined = "undefined"
  prettyTab _ LitNull = "null"

instance Pretty EVarName where
  prettyTab _ x = x


nakedSingleOrTuple :: [String] -> String
nakedSingleOrTuple [] = "()"
nakedSingleOrTuple [x] = x
nakedSingleOrTuple xs = "(" ++ intercalate ", " xs ++ ")"

instance Pretty (Exp a) where
  prettyTab t (EVar _ n) = prettyTab t n
  prettyTab t (EApp _ e1 args) = "(" ++ prettyTab t e1 ++ " " ++ nakedSingleOrTuple (map (prettyTab t) args) ++")"
  prettyTab t (EAbs _ args e) = "(\\" ++ nakedSingleOrTuple (map (prettyTab t) args) ++ " -> " ++ prettyTab t e ++ ")"
  prettyTab t (ELet _ n e1 e2) = "let " ++ prettyTab t n ++ " = " ++ prettyTab (t+1) e1 ++ "\n" ++ tab t ++ " in " ++ prettyTab (t+1) e2
  prettyTab t (ELit _ l) = prettyTab t l
  prettyTab t (EAssign _ n e1 e2) = prettyTab t n ++ " := " ++ prettyTab t e1 ++ ";\n" ++ tab t ++ prettyTab t e2
  prettyTab t (EPropAssign _ obj n e1 e2) = prettyTab t obj ++ "." ++ prettyTab t n ++ " := " ++ prettyTab t e1 ++ ";\n" ++ tab t ++ prettyTab t e2
  prettyTab t (EIndexAssign _ obj i e1 e2) = prettyTab t obj ++ "[" ++ prettyTab t i ++ "] := " ++ prettyTab t e1 ++ ";\n" ++ tab t ++ prettyTab t e2
  prettyTab t (EArray _ es) = "[" ++ intercalate ", " (map (prettyTab t) es) ++ "]"
  prettyTab t (ETuple _ es) = "(" ++ intercalate ", " (map (prettyTab t) es) ++ ")"
  prettyTab t (ERow _ isOpen props) = "{" ++ intercalate ", " (map (\(n,v) -> prettyTab t n ++ ": " ++ prettyTab t v) props)  ++ (if isOpen then ", " else "") ++ "}"
  prettyTab t (EIfThenElse _ ep e1 e2) = "(" ++ prettyTab t ep ++  " ? " ++ prettyTab t e1 ++ " : " ++ prettyTab t e2 ++ ")"
  prettyTab t (EProp _ e n) = prettyTab t e ++ "." ++ pretty n
  prettyTab t (EIndex _ e1 e2) = prettyTab t e1 ++ "[" ++ prettyTab t e2 ++ "]"
  prettyTab t (ENew _ e args) = "new " ++ prettyTab t e ++ " " ++ nakedSingleOrTuple (map (prettyTab t) args)

toChr :: Int -> Char
toChr n = chr (ord 'a' + (n - 1))

-- |
-- >>> prettyTab 0 (0 :: TVarName)
-- "a"
-- >>> prettyTab 0 (26 :: TVarName)
-- "aa"
instance Pretty TVarName where
  prettyTab _ n = foldr ((++) . (:[]) . toChr) [] (Digits.digits 26 (n + 1))

instance Pretty Bool where
  prettyTab _ x = show x

instance Pretty TypeId where
  prettyTab _ (TypeId n) = capitalize $ pretty n
    where capitalize [] = []
          capitalize (x:xs) = Char.toUpper x : xs

instance Pretty TBody where
  prettyTab t (TVar n) = prettyTab t n
  prettyTab _ x = show x

instance Pretty TConsName where
  prettyTab _ = show

instance Pretty RowTVar where
  prettyTab _ t = ".." ++ pretty (getRowTVar t)

instance Pretty t => Pretty (FType t) where
  prettyTab = prettyType

prettyType :: Pretty t => Int -> FType t -> String
prettyType n (TBody t) = prettyTab n t
prettyType n (TCons TFunc ts) = "(" ++ nakedSingleOrTuple args ++ " -> " ++ prettyTab n (last ts) ++ ")"
  where nonThisArgs = map (prettyTab n) . drop 1 $ init ts
        args = case ts of
                [] -> nonThisArgs
                (this:_) -> ("this: " ++ prettyTab n this) : nonThisArgs
-- prettyTab _ (TCons TFunc ts) = error $ "Malformed TFunc: " ++ intercalate ", " (map pretty ts)
prettyType n (TCons TArray [t]) = "[" ++ prettyTab n t ++ "]"
prettyType n (TCons TArray ts) = error $ "Malformed TArray: " ++ intercalate ", " (map (prettyTab n) ts)
prettyType n (TCons TTuple ts) = "(" ++ intercalate ", " (map (prettyTab n) ts) ++ ")"
prettyType n (TCons (TName name) ts) = "<Named Type: mu '" ++ pretty name ++ "'. " ++ (unwords $ map (prettyTab n) ts) ++ ">"
prettyType t (TRow list) = "{"
                          ++ intercalate ", " (map (\(n,v) -> prettyTab (t+1) n ++ ": " ++ prettyTab (t+1) v) (Map.toList props))
                          ++ (case r of
                               FlatRowEndTVar r' -> maybe "" ((", "++) . pretty) r'
                               FlatRowEndRec tid ts -> ", " ++ prettyTab t (TCons (TName tid) ts) -- TODO
                             )
                          ++ "}"
  where (props, r) = flattenRow list
prettyType n (TAmb v _) = prettyTab n v -- ++ "=(" ++ intercalate "|" (map (prettyTab n') ts') ++ ")"

unAmb :: FType t -> Maybe (TVarName, [t])
unAmb (TAmb v' ts') = Just (v', ts')
unAmb _ = Nothing

extractAmbs :: FType (Fix FType) -> [(TVarName, [Fix FType])]
extractAmbs t = catMaybes . map (unAmb . unFix) . Set.toList . Set.fromList . fixToList $ Fix t

prettyAmbs :: FType (Fix FType) -> String
prettyAmbs t = intercalate ", " $ map (\(n,ts) -> pretty n ++ " = (" ++ (intercalate " | " (map pretty ts)) ++ ")") $ extractAmbs t

--instance Pretty t => Pretty (Fix t) where
instance Pretty Type where
  prettyTab n (Fix t) = constraints ++ (prettyType n $ unFix $ removeAmbs $ Fix t)
    where constraints = case prettyAmbs t of
                         "" -> ""
                         constrStr -> constrStr ++ " => "
          removeAmbs (Fix t') =
            case unAmb t' of
             Nothing -> Fix $ fmap (removeAmbs) t'
             Just (v, _) -> Fix $ TBody $ TVar v

instance Pretty t => Pretty (TPred t) where
    prettyTab n (TPredEq v t) = prettyTab n v ++ " = " ++ prettyTab n t
    prettyTab n (TPredOr p1 p2) = "(" ++ prettyTab n p1 ++ " | " ++ prettyTab n p2 ++ ")"
    prettyTab n (TPredAnd p1 p2) = "(" ++ prettyTab n p1 ++ " & " ++ prettyTab n p2 ++ ")"

instance Pretty t => Pretty [TPred t] where
    prettyTab n p = intercalate ", " $ map (prettyTab n) p

instance Pretty t => Pretty (TQual t) where
    prettyTab n (TQual preds t) = prettyTab n preds ++ " => " ++ prettyTab n t
        
instance Pretty t => Pretty (TScheme t) where
  prettyTab n (TScheme vars t preds) = prettyTab n preds ++ " => " ++ forall ++ prettyTab n t
      where forall = if null vars then "" else "forall " ++ unwords (map (prettyTab n) vars) ++ ". "

instance (Pretty a, Pretty b) => Pretty (Either a b) where
    prettyTab n (Left x) = "Error: " ++ prettyTab n x
    prettyTab n (Right x) = prettyTab n x

instance (Pretty k, Pretty v) => Pretty (Map.Map k v) where
  prettyTab n s = "Map (" ++ str' ++ ")"
    where str' = intercalate ", " . map (\(k,v) -> prettyTab n k ++ " => " ++ prettyTab n v) . Map.toList $ s

instance (Pretty k) => Pretty (Set.Set k) where
  prettyTab n s = "Set {" ++ str' ++ "}"
    where str' = intercalate ", " . map (prettyTab n) . Set.toList $ s

instance Pretty TypeError where
  prettyTab _ (TypeError p s) = Pos.sourceName p ++ ":" ++ show (Pos.sourceLine p) ++ ":" ++ show (Pos.sourceColumn p) ++ ": Error: " ++ s

instance Pretty NameSource where
  prettyTab _ = show

instance Pretty VarId where
  prettyTab _ = show

instance Pretty InferState where
  prettyTab t (InferState ns sub preds vs vi tn) = "InferState { nameSource: "
                                                 ++ pretty ns ++ newline
                                                 ++ ", subst: " ++ pretty sub ++ newline
                                                 ++ ", preds: " ++ pretty preds ++ newline
                                                 ++ ", varSchemes: " ++ pretty vs ++ newline
                                                 ++ ", varInstances: " ++ pretty vi ++ newline
                                                 ++ ", namedTypes: " ++ pretty tn ++ newline
                                                 ++ "}"
    where newline = "\n" ++ tab (t+1)
