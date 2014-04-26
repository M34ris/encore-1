{-# LANGUAGE MultiParamTypeClasses, TypeSynonymInstances, FlexibleInstances #-}

module CodeGen.ClassDecl where

import CodeGen.Typeclasses
import CodeGen.CCodeNames
import CodeGen.MethodDecl
import qualified CodeGen.Context as Ctx

import CCode.Main
import CCode.PrettyCCode

import qualified AST as A

import Control.Monad.Reader

instance Translatable A.ClassDecl (Reader Ctx.Context (CCode Toplevel)) where
  translate cdecl = do
    method_impls <- mapM (\mdecl -> (local (Ctx.with_class cdecl) (translate mdecl))) (A.methods cdecl)
    return $ ConcatTL $ concat [
      [comment_section $ "Implementation of class " ++ (show $ A.cname cdecl)],
      [data_struct],
      [tracefun_decl],
      pony_msg_t_impls,
      [message_type_decl],
      [pony_actor_t_impl],
      method_impls,
      [dispatchfun_decl]
      ]
    where
      data_struct :: CCode Toplevel
      data_struct = TypeDef (data_rec_name $ A.cname cdecl)
                    (StructDecl ((data_rec_name $ A.cname cdecl)) $
                     zip
                     (map (Typ . show . A.ftype) (A.fields cdecl))
                     (map (Var . show . A.fname) (A.fields cdecl)))


      mthd_dispatch_clause :: A.ClassDecl -> A.MethodDecl -> (CCode Id, CCode Stat)
      mthd_dispatch_clause cdecl mdecl =
        ((method_msg_name (A.cname cdecl) (A.mname mdecl)),
         Statement
         (Call
          (AsExpr . AsLval $ (method_impl_name (A.cname cdecl) (A.mname mdecl)))
          [AsExpr . AsLval $ Var "p"]
         -- fixme what about arguments?
          ))
        
      dispatchfun_decl =
          (Function (Typ "static void") (class_dispatch_name $ A.cname cdecl)
           ([(embedCType "pony_actor_t*", Var "this"),
             (embedCType "void*", Var "p"),
             (embedCType "uint64_t", Var "id"),
             (embedCType "int", Var "argc"),
             (embedCType "pony_arg_t*", Var "argv")])
           (Switch (Var "id")
            ((Var "PONY_MAIN",

              Concat $ [alloc_instr,
                        (if (A.cname cdecl) == (A.Type "Main")
                         then Statement $ Call (AsExpr . AsLval $
                                                (method_impl_name (A.Type "Main") (A.Name "main")))
                                                [AsExpr . AsLval .Var $ "p"]
                         else Concat [])]) :

             (Var "MSG_alloc", alloc_instr) :

             (map (mthd_dispatch_clause cdecl) (A.methods cdecl)))
             (Embed "printf(\"error, got invalid id: %llu\",id);")))
          where
            alloc_instr = Concat $ map Statement $
                          [(AsLval $ Var "p") `Assign`
                           (Call (AsExpr . AsLval . Var $ "pony_alloc")
                                     [(Call 
                                       (AsExpr . AsLval . Var $ "sizeof")
                                       [Embed $ show (data_rec_name $ A.cname cdecl)])]),
                           Call (AsExpr . AsLval . Var $ "pony_set")
                                    [AsExpr . AsLval . Var $ "p"]]

      tracefun_decl = (Function
                       (embedCType "static void")
                       (class_trace_fn_name (A.cname cdecl))
                       [(embedCType "void*", Var "p")]
                       (Embed "//Todo!"))
      message_type_decl = Function (embedCType "static pony_msg_t*")
                          (class_message_type_name $ A.cname cdecl)
                          [(embedCType "uint64_t", Var "id")]
                          (Concat [(Switch (Var "id")
                                   ((Var "MSG_alloc", Statement $ Embed $ "return &m_MSG_alloc")
                                    :(map (\mdecl -> message_type_clause (A.cname cdecl) (A.mname mdecl))
                                      (A.methods cdecl)))
                                   (Concat [])),
                                  Statement (Embed "return NULL")])
        where
          message_type_clause :: A.Type -> A.Name -> (CCode Id, CCode Stat)
          message_type_clause cname mname =
            (method_msg_name cname mname,
             Statement $ Embed $ "return &" ++ show (method_message_type_name cname mname))

-- * implement the message types:
--      static pony_msg_t m_Other_init = {0, {{NULL, 0, PONY_PRIMITIVE}}};
--      static pony_msg_t m_Other_work = {2, {{NULL, 0, PONY_PRIMITIVE}}};


      pony_msg_t_impls :: [CCode Toplevel]
      pony_msg_t_impls = map pony_msg_t_impl (A.methods cdecl)

      pony_msg_t_impl :: A.MethodDecl -> CCode Toplevel
      pony_msg_t_impl mdecl = 
          Embed $ "static pony_msg_t " ++ 
          show (method_message_type_name
                (A.cname cdecl) 
                (A.mname mdecl)) ++
                   "= {" ++
                   (show $ length (A.mparams mdecl)) ++
                   ", {{NULL, 0, PONY_PRIMITIVE}}};"
        
      pony_actor_t_impl :: CCode Toplevel
      pony_actor_t_impl = EmbedC $
                          Statement (Assign
                                     (Embed $ "static pony_actor_type_t " ++ show (actor_rec_name (A.cname cdecl)))
                                     (Record [AsExpr . AsLval . Var $ ("ID_"++(show $ A.cname cdecl)),
                                              tracefun_rec,
                                              (EmbedC $ class_message_type_name (A.cname cdecl)),
                                              (EmbedC $ class_dispatch_name $ A.cname cdecl)]))

      tracefun_rec :: CCode Expr
      tracefun_rec = Record [AsExpr . AsLval $ (class_trace_fn_name $ A.cname cdecl),
                             Call (AsExpr . AsLval . Var $ "sizeof") [Embed . show $ data_rec_name $ A.cname cdecl],
                             AsExpr . AsLval . Var $ "PONY_ACTOR"]

comment_section :: String -> CCode a
comment_section s = EmbedC $ Concat $ [Embed $ take (5 + length s) $ repeat '/',
                         Embed $ "// " ++ s]

main_dispatch_clause = (Var "PONY_MAIN",
                        Concat $ map Statement [
                                      Assign (Decl $ (embedCType "Main_data*", Var "d")) (Call (AsExpr . AsLval . Var $ "pony_alloc") [(Call (AsExpr . AsLval . Var $ "sizeof") [AsExpr . AsLval . Var $ "Main_data"])]),
                                      Call (AsExpr . AsLval . Var $ "pony_set") [AsExpr . AsLval . Var $ "d"],
                                      Call (AsExpr . AsLval . Var $ "Main_main") [AsExpr . AsLval . Var $ "d"]])

instance FwdDeclaration A.ClassDecl (CCode Toplevel) where
  fwd_decls cdecl =
      EmbedC $ Concat $ (comment_section "Forward declarations") :
        map (Statement . Embed)
                ["static pony_actor_type_t " ++ (show . actor_rec_name $ A.cname cdecl),
                 "static void " ++ (show $ A.cname cdecl) ++
                 "_dispatch(pony_actor_t*, void*, uint64_t, int, pony_arg_t*)"]
