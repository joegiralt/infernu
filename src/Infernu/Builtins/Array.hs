{-# LANGUAGE TupleSections #-}
module Infernu.Builtins.Array
       (arrayRowType)
       where

import           Control.Monad         (foldM)

import           Infernu.Builtins.Util
import           Infernu.InferState    (Infer)
import           Infernu.Prelude
import           Infernu.Types
import           Infernu.Expr       (EPropName(..))

arrayProps :: Type -> [(String, TypeScheme)]
arrayProps elemType = let aType = array elemType in
  [ ("length",  ty number)
  , ("concat",  ty $ func aType aType aType)
     -- TODO support thisArg (requires type variables)
  , ("every",   ts [] $ func aType (funcN [tvar 1, elemType] boolean) boolean) -- missing thisArg
  , ("filter",  ts [] $ func aType (funcN [tvar 1, elemType] boolean) aType) -- missing thisArg
  , ("forEach", ts [2] $ func aType (funcN [tvar 1, elemType] (tvar 2)) undef) -- missing thisArg
    -- TODO support optional argument for fromIndex (last parameter)
  , ("indexOf", ty $ funcN [aType, elemType, number] number)
  , ("join",    ty $ func aType string string)
  , ("lastIndexOf", ty $ func aType number number)
  , ("map",     ts [2] $ func aType (funcN [tvar 1, elemType] (tvar 2)) (array $ tvar 2))
  , ("pop",     ty $ funcN [aType] elemType)
  , ("push",    ty $ funcN [aType, elemType] number)
  , ("reduce",  ts [1] $ funcN [aType, funcN [tvar 0, tvar 1, elemType] (tvar 1), (tvar 1)] (tvar 1))
  , ("reverse", ty $ funcN [aType] aType)
  , ("shift",   ty $ funcN [aType] elemType)
  , ("slice",   ty $ funcN [aType, number, number] aType)
  , ("some",    ts [] $ func aType (funcN [tvar 0, elemType] boolean) aType) -- missing thisArg
  , ("sort",    ts [] $ func aType (funcN [tvar 0, elemType, elemType] number) aType)
  , ("splice",  ty $ funcN [aType, number, number] aType)
  , ("unshift", ty $ funcN [aType] elemType)
  ]

-- TODO: when inserting builtin types, do fresh renaming of scheme qvars
arrayRowType :: Type -> Infer (TRowList Type)
arrayRowType elemType = TRowProp (TPropGetName EPropSetIndex) (ty $ funcN [aType, number, elemType] undef)
                        . TRowProp (TPropGetName EPropGetIndex) (ty $ func aType number elemType)
                        <$> foldM addProp (TRowEnd Nothing) (arrayProps elemType)
  where aType = array elemType
