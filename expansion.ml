(*




*)

type param = Param of string

type op =
  | Hyp
  | ColonHyp
  | Eq
  | ColonEq
  | Ques
  | ColonQues
  | Plus
  | ColonPlus
  | Percent
  | PercentPercent
  | Hash
  | HashHash

type word
  = WLiteral of string
  | WParam of param
  | WArith of string
  | WTilde of string
  | WSubst of param * op * word
  | WLength of param
  | WCommand of string
  | WDoubleQuote of string
  | WCat of word * word

let cat (w1 : word) (w2: word) = match (w1, w2) with
  | WLiteral str1, WLiteral str2 = WLiteral (str1 ^ str2)
  | _, _ -> WCat (w1, w2)

let rec parse_word (str : char list) : word = str match
  (* Section 2.3, bullet 1 *)
  | [] -> WLiteral ""
  (* Section 2.2.1 *)
  | '\' :: '\n' :: rest -> parse_word rest
  | '\' :: ch :: rest -> cat (WLiteral (Char.to_string ch)) (parse_word rest)
  (* Section 2.2.2 *)
  | '\'' :: rest -> parse_word_in_single_quotes rest []
  (* Section 2.3, bullet 5 *)
  | '$' :: '(' :: '(' :: rest -> parse_arith_word rest

and parse_arith_word (str : char list) : word = str match
  | ')' :: ')' :: rest

(* Section 2.2.2 *)
and parse_word_in_single_quotes (str : char list) (chars : char list): word =
  match chars with
  | '\'' :: rest ->  cat (WLiteral (List.of_char_list (List.rev chars))) parse_word rest
  | ch :: rest -> parse_word_in_single_quotes rest (ch :: chars)
  | [] -> failwith "EOF reading a single-quoted string"

