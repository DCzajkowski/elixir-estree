defmodule ESTree.Tools.Generator do
  @moduledoc """
  Responsible for taking JavaScript AST and converting
  it to JavaScript code
  """

  @unary_operators [:-, :+ , :! , :"~" , :typeof , :void , :delete]
  
  @binary_operators [:== , :!= , :=== , :!== , :< , :<= , :> , :>= , 
                            :"<<" , :">>" , :>>> , :+ , :- , :* , :/ , :% , :| , 
                            :^ , :& , :in , :instanceof]

  @logical_operators  [:|| , :&&]

  @assignment_operators [:= , :"+=" , :"-=" , :"*=" , :"/=" ,
                         :"%=" , :"<<=" , :">>=" , :">>>=" ,
                         :"|=" , :"^=" , :"&="]

  @update_operators [:++, :--]

  @spec generate(ESTree.unary_operator | ESTree.binary_operator | ESTree.logical_operator | ESTree.assignment_operator | ESTree.update_operator | ESTree.Node.t) :: binary
  def generate(unary_operator) when unary_operator in @unary_operators do
    to_string(unary_operator)
  end

  def generate(binary_operator) when binary_operator in @binary_operators do
    to_string(binary_operator)
  end

  def generate(logical_operator) when logical_operator in @logical_operators  do
    to_string(logical_operator)
  end

  def generate(assignment_operator) when assignment_operator in @assignment_operators do
    to_string(assignment_operator)
  end

  def generate(update_operator) when update_operator in @update_operators do
    to_string(update_operator)
  end

  def generate(nil) do
    ""
  end
  
  def generate(%ESTree.Identifier{name: name}) do
    to_string(name)
  end

  def generate(%ESTree.Literal{value: nil})  do
    "null"
  end
  
  def generate(%ESTree.Literal{value: %{}, regex: regex}) do
    "/#{regex.pattern}/#{regex.flags}"
  end

  def generate(%ESTree.Literal{value: value}) when is_atom(value) do
    "'#{to_string(value)}'"
  end
  
  def generate(%ESTree.Literal{value: value}) when is_binary(value) do
    value = String.replace(value, "\n", "\\n")
    |> String.replace("\t", "\\t")
    
    "'#{value}'"
  end

  def generate(%ESTree.Literal{value: value})  do
    to_string(value)
  end

  def generate(%ESTree.Program{body: []}) do
    ""
  end
  
  def generate(%ESTree.Program{body: body}) do
    Enum.map_join(body, "\n", &generate(&1))
  end

  def generate(%ESTree.FunctionDeclaration{} = ast) do
    generator = if ast.generator do
      "*"
    else
      ""
    end
    
    params = params_and_defaults(ast.params, ast.defaults)
    id = generate(ast.id)
    
    "function#{generator} #{id}(#{params})#{generate(ast.body)}"
  end

  def generate(%ESTree.FunctionExpression{} = ast) do
    generator = if ast.generator do
      "*"
    else
      ""
    end
    params = params_and_defaults(ast.params, ast.defaults)
    
    "function#{generator}(#{params})#{generate(ast.body)}"
  end
  
  def generate(%ESTree.EmptyStatement{}) do
    ";"
  end
  
  def generate(%ESTree.BlockStatement{body: body}) do
   "{" <> Enum.map_join(body, "\n", &generate(&1)) <> "}"
  end

  def generate(%ESTree.ExpressionStatement{} = ast) do
    "#{generate(ast.expression)};"
  end

  def generate(%ESTree.IfStatement{test: test, consequent: consequent, alternate: alternate}) do
    test = generate(test)
    consequent = generate(consequent)
    result = "if(#{test}) #{consequent}"

    if alternate do
      result = result <> " else #{generate(alternate)}"
    end

    result
  end

  def generate(%ESTree.LabeledStatement{label: label, body: body}) do
    """
    #{generate(label)}:
    #{generate(body)}
    """
  end

  def generate(%ESTree.BreakStatement{label: nil}) do
    "break;"
  end
  
  def generate(%ESTree.BreakStatement{label: label}) do
    "break #{generate(label)};"
  end

  def generate(%ESTree.ContinueStatement{label: nil}) do
    "continue;"
  end
  
  def generate(%ESTree.ContinueStatement{label: label}) do
    "continue #{generate(label)};"
  end

  def generate(%ESTree.WithStatement{object: object, body: body}) do
    "with(#{generate(object)})#{generate(body)}"
  end

  def generate(%ESTree.SwitchStatement{discriminant: discriminant, cases: cases}) do
    cases = Enum.map_join(cases, "\n", &generate(&1))
    "switch(#{generate(discriminant)}){ #{cases} }"
  end

  def generate(%ESTree.ReturnStatement{argument: argument}) do
    "return #{generate(argument)};"
  end

  def generate(%ESTree.ThrowStatement{argument: argument}) do
    "throw #{generate(argument)};"
  end

  def generate(%ESTree.TryStatement{block: block, handler: handler, finalizer: nil}) do
    "try#{generate(block)}#{generate(handler)}"
  end

  def generate(%ESTree.TryStatement{block: block, handler: nil, finalizer: finalizer}) do
    "try#{generate(block)}finally#{generate(finalizer)}"
  end
  
  def generate(%ESTree.TryStatement{block: block, handler: handler, finalizer: finalizer}) do
    "try#{generate(block)}#{generate(handler)}finally#{generate(finalizer)}"
  end

  def generate(%ESTree.WhileStatement{test: test, body: body}) do
    "while(#{generate(test)}) #{generate(body)}"
  end

  def generate(%ESTree.DoWhileStatement{test: test, body: body}) do
    "do #{generate(body)} while(#{generate(test)})"
  end

  def generate(%ESTree.ForStatement{init: init, test: test, update: update, body: body}) do
    init = generate(init)
    test = generate(test)
    update = generate(update)
    body = generate(body)

    "for(#{init};#{test};#{update}) #{body}"
  end

  def generate(%ESTree.ForInStatement{left: left, right: right, body: body}) do
    left = generate(left)
    right = generate(right)
    body = generate(body)

    "for(#{left} in #{right}) #{body}"
  end

  def generate(%ESTree.DebuggerStatement{}) do
    "debugger;"
  end

  def generate(%ESTree.VariableDeclaration{kind: kind, declarations: declarations}) do

    ids = Enum.map_join(declarations, ",",  fn(x) -> generate(x.id) end)
    inits = Enum.map_join(declarations, ",", fn(x) -> generate(x.init) end) 

    "#{to_string(kind)} #{ids} = #{inits};"
  end

  def generate(%ESTree.VariableDeclarator{id: id, init: nil}) do
    generate(id)
  end

  def generate(%ESTree.VariableDeclarator{id: id, init: init}) do
    "#{generate(id)} = #{generate(init)}"
  end

  def generate(%ESTree.ThisExpression{}) do
    "this"
  end

  def generate(%ESTree.ArrayExpression{elements: nil}) do
    ""
  end
  
  def generate(%ESTree.ArrayExpression{elements: elements}) do
   "[" <> Enum.map_join(elements, ",", &generate(&1)) <> "]"
  end

  def generate(%ESTree.ObjectExpression{properties: properties}) do
   "{" <> Enum.map_join(properties, ",", &generate(&1)) <> "}"
  end

  def generate(%ESTree.Property{key: key, value: value, kind: :init, shorthand: false, method: false, computed: false}) do
    key = generate(key)
    value = generate(value)

    "#{key}: #{value}"
  end

  def generate(%ESTree.Property{key: key, value: _, kind: :init, shorthand: true, method: false, computed: false}) do
    key = generate(key)

    "#{key}"
  end

  def generate(%ESTree.Property{key: key, value: value, kind: :init, shorthand: false, method: false, computed: true}) do
    key = generate(key)
    value = generate(value)

    "[#{key}]: #{value}"
  end

  def generate(%ESTree.Property{key: key, value: %ESTree.FunctionExpression{body: body}, kind: :get, shorthand: false, method: true, computed: false}) do
    key = generate(key)
    value = generate(body)

    "#{key}() #{value}"
  end

  
  def generate(%ESTree.Property{key: key, value: %ESTree.FunctionExpression{body: body}, kind: :get}) do
    key = generate(key)
    value = generate(body)

    "get #{key}() #{value}"
  end

  def generate(%ESTree.Property{key: key, value: %ESTree.FunctionExpression{params: params, body: body}, kind: :set, shorthand: false, method: true, computed: false}) do
    key = generate(key)
    param = generate(hd(params))
    value = generate(body)

    "#{key}(#{param}) #{value}"
  end

  
  def generate(%ESTree.Property{key: key, value: %ESTree.FunctionExpression{params: params, body: body}, kind: :set}) do
    key = generate(key)
    param = generate(hd(params))
    value = generate(body)

    "set #{key}(#{param}) #{value}"
  end

  def generate(%ESTree.SequenceExpression{expressions: expressions}) do
    Enum.map_join(expressions, ",", &generate(&1))
  end

  def generate(%ESTree.UnaryExpression{operator: operator, prefix: true, argument: argument}) do
    "#{generate(operator)}#{generate(argument)}"
  end

  def generate(%ESTree.UnaryExpression{operator: operator, prefix: false, argument: argument}) do
    "#{generate(argument)}#{generate(operator)}"
  end

  def generate(%ESTree.BinaryExpression{operator: operator, left: left, right: right}) do
    operator = generate(operator)
    left = generate(left)
    right = generate(right)

    "#{left} #{operator} #{right}"
  end

  def generate(%ESTree.AssignmentExpression{operator: operator, left: left, right: right}) do
    operator = generate(operator)
    left = generate(left)
    right = generate(right)

    "#{left} #{operator} #{right}"
  end

  def generate(%ESTree.UpdateExpression{operator: operator, prefix: true, argument: argument}) do
    "#{generate(operator)}#{generate(argument)}"
  end

  def generate(%ESTree.UpdateExpression{operator: operator, prefix: false, argument: argument}) do
    "#{generate(argument)}#{generate(operator)}"
  end

  def generate(%ESTree.LogicalExpression{operator: operator, left: left, right: right}) do
    operator = generate(operator)
    left = generate(left)
    right = generate(right)

    "#{left} #{operator} #{right}"
  end

  def generate(%ESTree.ConditionalStatement{test: test, alternate: alternate, consequent: consequent}) do
    test = generate(test)
    alternate = generate(alternate)
    consequent = generate(consequent)

    "#{test} ? #{consequent} : #{alternate}"
  end

  def generate(%ESTree.CallExpression{callee: %ESTree.Super{}, arguments: arguments}) do
    arguments = Enum.map_join(arguments, ",", &generate(&1))

    "super(#{arguments})"
  end
  
  def generate(%ESTree.CallExpression{callee: callee, arguments: arguments}) do
    callee = generate(callee)
    arguments = Enum.map_join(arguments, ",", &generate(&1))

    "#{callee}(#{arguments})"
  end

  def generate(%ESTree.NewExpression{callee: callee, arguments: arguments}) do
    callee = generate(callee)
    arguments = Enum.map_join(arguments, ",", &generate(&1))

    "new #{callee}(#{arguments})"
  end

  def generate(%ESTree.MemberExpression{object: %ESTree.Super{}, property: property, computed: true}) do
    property = generate(property)
    "super[#{property}]"
  end

  def generate(%ESTree.MemberExpression{object: object, property: property, computed: true}) do
    object = generate(object)
    property = generate(property)
    "#{object}[#{property}]"
  end

  def generate(%ESTree.MemberExpression{object: %ESTree.Super{}, property: property, computed: false}) do
    property = generate(property)
    "super.#{property}"
  end
  
  def generate(%ESTree.MemberExpression{object: object, property: property, computed: false}) do
    object = generate(object)
    property = generate(property)
    "#{object}.#{property}"
  end

  def generate(%ESTree.SwitchCase{test: nil, consequent: consequent}) do
    consequent = Enum.map_join(consequent, "\n", &generate(&1))
    """
    default:
      #{consequent}
    """
  end
  
  def generate(%ESTree.SwitchCase{test: test, consequent: consequent}) do
    test = generate(test)
    consequent = Enum.map_join(consequent, "\n", &generate(&1))

    """
    case #{test}:
      #{consequent}
    """
  end

  def generate(%ESTree.CatchClause{param: param, body: body}) do
    param = generate(param)
    body = generate(body)

    "catch(#{param}) #{body}"
  end

  def generate(%ESTree.ForOfStatement{left: left, right: right, body: body}) do
    left = generate(left)
    right = generate(right)
    body = generate(body)

    "for(#{left} of #{right}) #{body}"
  end

  def generate(%ESTree.SpreadElement{argument: argument}) do
    "...#{generate(argument)}"
  end

  def generate(%ESTree.RestElement{argument: argument}) do
    "...#{generate(argument)}"
  end

  def generate(%ESTree.ArrowFunctionExpression{} = ast) do
    generator = if ast.generator
    do
      "*"
    else
      ""
    end
    
    params = params_and_defaults(ast.params, ast.defaults)
    
    "(#{params})#{generator} => #{generate(ast.body)}"
  end

  def generate(%ESTree.YieldExpression{argument: argument}) do
    "yield #{generate(argument)}"
  end

  def generate(%ESTree.ObjectPattern{properties: properties}) do
     "{" <> Enum.map_join(properties, ",", &generate(&1)) <> "}"
  end

  def generate(%ESTree.ArrayPattern{elements: elements}) do
     "[" <> Enum.map_join(elements, ",", &generate(&1)) <> "]"
  end

  def generate(%ESTree.AssignmentPattern{left: left, right: right}) do
    left = generate(left)
    right = generate(right)

    "#{left} = #{right}"
  end

  
  def generate(%ESTree.ClassDeclaration{id: id, body: body, superClass: nil}) do
    id = generate(id)
    body = generate(body)

    "class #{id} #{body}"
  end

  
  def generate(%ESTree.ClassDeclaration{id: id, body: body, superClass: superClass}) do
    id = generate(id)
    body = generate(body)
    superClass = generate(superClass)

    "class #{id} extends #{superClass} #{body}"
  end


  def generate(%ESTree.ClassExpression{body: body, superClass: nil}) do
    body = generate(body)

    "class #{body}"
  end

  
  def generate(%ESTree.ClassExpression{body: body, superClass: superClass}) do
    body = generate(body)
    superClass = generate(superClass)

    "class extends #{superClass} #{body}"
  end

  def generate(%ESTree.ClassBody{body: body}) do
    body = Enum.map_join(body, "\n", &generate(&1))

    "{ #{body} }"
  end

  def generate(%ESTree.MethodDefinition{key: _key, value: %ESTree.FunctionExpression{ params: params, defaults: defaults, body: body}, kind: :constructor}) do
    params = params_and_defaults(params, defaults)
    body = generate(body)

    "constructor(#{params})#{body}"      
  end
  
  def generate(%ESTree.MethodDefinition{key: key, value: %ESTree.FunctionExpression{ params: params, defaults: defaults, body: body}, kind: :method, computed: false, static: false}) do
    key = generate(key)
    params = params_and_defaults(params, defaults)
    body = generate(body)

    "#{key}(#{params})#{body}"
  end

  def generate(%ESTree.MethodDefinition{key: key, value: %ESTree.FunctionExpression{ params: params, defaults: defaults, body: body}, kind: :method, computed: false, static: true}) do
    key = generate(key)
    params = params_and_defaults(params, defaults)
    body = generate(body)

    "static #{key}(#{params})#{body}"
  end

  def generate(%ESTree.MethodDefinition{key: key, value: %ESTree.FunctionExpression{ params: params, defaults: defaults, body: body}, kind: :method, computed: true, static: false}) do
    key = generate(key)
    params = params_and_defaults(params, defaults)
    body = generate(body)

    "[#{key}](#{params})#{body}"
  end

  def generate(%ESTree.MethodDefinition{key: key, value: %ESTree.FunctionExpression{ params: params, defaults: defaults, body: body}, kind: :method, computed: true, static: true}) do
    key = generate(key)
    params = params_and_defaults(params, defaults)
    body = generate(body)

    "static [#{key}](#{params})#{body}"
  end

  def generate(%ESTree.MetaProperty{meta: meta, property: property}) do
    meta = generate(meta)
    property = generate(property)

    "#{meta}.#{property}"
  end

  
  def generate(%ESTree.ImportDeclaration{specifiers: specifiers, source: source}) do
    specifiers = Enum.map_join(specifiers, ",", &generate(&1))
    source = generate(source)

    "import #{specifiers} from #{source};"
  end

  
  def generate(%ESTree.ImportSpecifier{local: local, imported: imported}) do
    local = generate(local)
    imported = generate(imported)

    if local == imported do
      "{#{local}}"
    else
      "{#{imported} as #{local} }"
    end
  end

  def generate(%ESTree.ImportDefaultSpecifier{local: local}) do
    generate(local)
  end

  def generate(%ESTree.ImportNamespaceSpecifier{local: local}) do
    local = generate(local)

    "* as #{local}"
  end

  def generate(%ESTree.ExportNamedDeclaration{declaration: declaration, specifiers: [], source: nil}) do
     declaration = generate(declaration)
    "export #{declaration};"
  end
  
  def generate(%ESTree.ExportNamedDeclaration{declaration: nil, specifiers: specifiers, source: nil}) do
    specifiers = Enum.map_join(specifiers, ",", &generate(&1))

    "export #{specifiers};"
  end

  def generate(%ESTree.ExportNamedDeclaration{declaration: nil, specifiers: specifiers, source: source}) do
    specifiers = Enum.map_join(specifiers, ",", &generate(&1))
    source = generate(source)
    
    "export #{specifiers} from #{source};"
  end
  
  def generate(%ESTree.ExportSpecifier{local: local, exported: exported}) do
    local = generate(local)
    exported = generate(exported)

    if local == exported do
      "{#{local}}"
    else
      "{#{exported} as #{local} }"
    end
  end

  def generate(%ESTree.ExportDefaultDeclaration{declaration: declaration}) do
    declaration = generate(declaration)

    "export default #{declaration};"
  end

  def generate(%ESTree.ExportAllDeclaration{source: source}) do
    source = generate(source)
    "export * from #{source};"
  end
  
  defp params_and_defaults(params, []) do
    Enum.map_join(params, ",", &generate(&1))
  end  
  
  defp params_and_defaults(params, defaults) do
    Enum.zip(params, defaults)
    |> Enum.map_join(",", fn
      {p, nil} -> "#{generate(p)}"
      {p, d} ->  "#{generate(p)} = #{generate(d)}"
    end)
  end
end
