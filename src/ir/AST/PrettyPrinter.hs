{-# LANGUAGE NamedFieldPuns #-}

{-|

Prints the source code that an "AST.AST" represents. Each node in
the abstract syntax tree has a corresponding pretty-print function
(although not all are exported)

-}

module AST.PrettyPrinter (ppExpr, ppProgram, ppParamDecl, 
                          ppFieldDecl, indent, ppSugared) where

-- Library dependencies
import Text.PrettyPrint

-- Module dependencies
import Identifiers
import Types
import AST.AST

ppClass = text "class"
ppSkip = text "()"
ppLet = text "let"
ppIn = text "in"
ppIf = text "if"
ppThen = text "then"
ppElse = text "else"
ppUnless = text "unless"
ppWhile = text "while"
ppRepeat = text "repeat"
ppGet = text "get"
ppNull = text "null"
ppTrue = text "true"
ppFalse = text "false"
ppNew = text "new"
ppPrint = text "print"
ppExit = text "exit"
ppEmbed = text "embed"
ppDot = text "."
ppBang = text "!"
ppColon = text ":"
ppComma = text ","
ppSemicolon = text ";"
ppEquals = text "="
ppSpace = text " "
ppLambda = text "\\"
ppArrow = text "->"

indent = nest 2

commaSep l = cat $ punctuate (ppComma <> ppSpace) l

ppName :: Name -> Doc
ppName (Name x) = text x

ppType :: Type -> Doc
ppType = text . show

ppProgram :: Program -> Doc
ppProgram (Program (EmbedTL _ header code) importDecls functions classDecls) = 
    text "embed" $+$ text header $+$ text "body" $+$ text code $+$ text "end" $+$
         vcat (map ppImportDecl importDecls) $+$
         vcat (map ppFunction functions) $+$
         vcat (map ppClassDecl classDecls)

ppImportDecl :: ImportDecl -> Doc
ppImportDecl Import {itarget} = text "import" <+> ppName itarget

ppFunction :: Function -> Doc
ppFunction Function {funname, funtype, funparams, funbody} = 
    text "def" <+>
    ppName funname <> 
    parens (commaSep (map ppParamDecl funparams)) <+>
    text ":" <+> ppType funtype $+$
    (indent (ppExpr funbody))

ppClassDecl :: ClassDecl -> Doc
ppClassDecl Class {cname, fields, methods} = 
    ppClass <+> ppType cname $+$
             (indent $
                   vcat (map ppFieldDecl fields) $$
                   vcat (map ppMethodDecl methods))

ppFieldDecl :: FieldDecl -> Doc
ppFieldDecl Field {fname, ftype} = ppName fname <+> ppColon <+> ppType ftype

ppParamDecl :: ParamDecl -> Doc
ppParamDecl (Param {pname, ptype}) =  ppName pname <+> text ":" <+> ppType ptype

ppMethodDecl :: MethodDecl -> Doc
ppMethodDecl Method {mname, mtype, mparams, mbody} = 
    text "def" <+>
    ppName mname <> 
    parens (commaSep (map ppParamDecl mparams)) <+>
    text ":" <+> ppType mtype $+$
    (indent (ppExpr mbody))

isSimple :: Expr -> Bool
isSimple VarAccess {} = True
isSimple FieldAccess {target} = isSimple target
isSimple MethodCall {target} = isSimple target
isSimple MessageSend {target} = isSimple target
isSimple FunctionCall {} = True
isSimple _ = False

maybeParens :: Expr -> Doc
maybeParens e 
    | isSimple e = ppExpr e
    | otherwise  = parens $ ppExpr e

ppSugared :: Expr -> Doc
ppSugared e = case getSugared e of
                Just e' -> ppExpr e'
                Nothing -> ppExpr e

ppExpr :: Expr -> Doc
ppExpr Skip {} = ppSkip
ppExpr MethodCall {target, name, args} = 
    maybeParens target <> ppDot <> ppName name <> 
      parens (commaSep (map ppExpr args))
ppExpr MessageSend {target, name, args} = 
    maybeParens target <> ppBang <> ppName name <> 
      parens (commaSep (map ppExpr args))
ppExpr FunctionCall {name, args} = 
    ppName name <> parens (commaSep (map ppExpr args))
ppExpr Closure {eparams, body} = 
    ppLambda <> parens (commaSep (map ppParamDecl eparams)) <+> ppArrow <+> ppExpr body
ppExpr Let {decls, body} = 
    ppLet <+> vcat (map (\(Name x, e) -> text x <+> equals <+> ppExpr e) decls) $+$ ppIn $+$ 
      indent (ppExpr body)
ppExpr Seq {eseq} = braces $ vcat $ punctuate ppSemicolon (map ppExpr eseq)
ppExpr IfThenElse {cond, thn, els} = 
    ppIf <+> ppExpr cond <+> ppThen $+$
         indent (ppExpr thn) $+$
    ppElse $+$
         indent (ppExpr els)
ppExpr IfThen {cond, thn} = 
    ppIf <+> ppExpr cond <+> ppThen $+$
         indent (ppExpr thn)
ppExpr Unless {cond, thn} = 
    ppUnless <+> ppExpr cond <+> ppThen $+$
         indent (ppExpr thn)
ppExpr While {cond, body} = 
    ppWhile <+> ppExpr cond $+$
         indent (ppExpr body)
ppExpr Repeat {name, times, body} = 
    ppRepeat <+> (ppExpr times) <> comma <+> (ppName name) $+$
         indent (ppExpr body)
ppExpr Get {val} = ppGet <+> ppExpr val
ppExpr FieldAccess {target, name} = maybeParens target <> ppDot <> ppName name
ppExpr VarAccess {name} = ppName name
ppExpr Assign {lhs, rhs} = ppExpr lhs <+> ppEquals <+> ppExpr rhs
ppExpr Null {} = ppNull
ppExpr BTrue {} = ppTrue
ppExpr BFalse {} = ppFalse
ppExpr NewWithInit {ty, args} = ppNew <+> ppType ty <> parens (commaSep (map ppExpr args))
ppExpr New {ty} = ppNew <+> ppType ty
ppExpr Print {stringLit, args} = ppPrint <> parens (doubleQuotes (text stringLit) <> comma <+> commaSep (map ppExpr args))
ppExpr Exit {args} = ppExit <> parens (commaSep (map ppExpr args))
ppExpr StringLiteral {stringLit} = doubleQuotes (text stringLit)
ppExpr IntLiteral {intLit} = int intLit
ppExpr RealLiteral {realLit} = double realLit
ppExpr Embed {ty, code} = ppEmbed <+> ppType ty <+> doubleQuotes (text code)
ppExpr Unary {op, operand} = ppUnary op <+> ppExpr operand
ppExpr Binop {op, loper, roper} = ppExpr loper <+> ppBinop op <+> ppExpr roper
ppExpr TypedExpr {body, ty} = ppExpr body <+> ppColon <+> ppType ty

ppUnary :: Op -> Doc
ppUnary Identifiers.NOT = text "not"

ppBinop :: Op -> Doc
ppBinop Identifiers.AND = text "and"
ppBinop Identifiers.OR = text "or"
ppBinop Identifiers.LT  = text "<"
ppBinop Identifiers.GT  = text ">"
ppBinop Identifiers.LTE  = text "<="
ppBinop Identifiers.GTE  = text ">="
ppBinop Identifiers.EQ  = text "=="
ppBinop Identifiers.NEQ = text "!="
ppBinop Identifiers.PLUS  = text "+"
ppBinop Identifiers.MINUS = text "-"
ppBinop Identifiers.TIMES  = text "*"
ppBinop Identifiers.DIV = text "/"
ppBinop Identifiers.MOD = text "%"
