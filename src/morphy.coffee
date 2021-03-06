_ = require "underscore"
fs = require "fs"
Word = require "./Word"
require './String.js'
memoize = require "./memoize"
{Word} = require "./Word"

EXCEPTIONS = JSON.parse(fs.readFileSync(__dirname + "/../data/EXCEPTIONS.json"))
DICTIONARY = JSON.parse(fs.readFileSync(__dirname + "/../data/DICTIONARY.json"))

MORPHY_SUBSTITUTIONS = {
  NOUN: [{ suffix: 's', ending: ''},
  { suffix: 'ses', ending: 's'},
  { suffix: 'ves', ending: 'f'},
  { suffix: 'xes', ending: 'x'},
  { suffix: 'zes', ending: 'z'},
  { suffix: 'ches', ending: 'ch'},
  { suffix: 'shes', ending: 'sh'},
  { suffix: 'men', ending: 'man'},
  { suffix: 'ies', ending: 'y'}],
  VERB: [{ suffix: 's', ending: ''},
  { suffix: 'ies', ending: 'y'},
  { suffix: 'es', ending: 'e'},
  { suffix: 'es', ending: ''},
  { suffix: 'ed', ending: 'e'},
  { suffix: 'ed', ending: ''},
  { suffix: 'ing', ending: 'e'},
  { suffix: 'ing', ending: ''}],
  ADJECTIVE: [{ suffix: 'er', ending: ''},
  { suffix: 'est', ending: ''},
  { suffix: 'er', ending: 'e'},
  { suffix: 'est', ending: 'e'}]
}

morphy = (input_str, pos) ->
  rulesOfDetachment = (word, substitutions) ->
    result = []
    DICTIONARY
    .filter( (elem) -> elem.lemma is word)
    .forEach (elem) ->
      if elem.pos is pos
        obj = new Word(elem.lemma)
        obj.part_of_speech = elem.pos
        result.push obj

    i = 0
    while i < substitutions.length
      suffix = substitutions[i].suffix
      new_ending = substitutions[i].ending
      if word.endsWith(suffix) is true
        new_word = word.substring(0, word.length - suffix.length) + new_ending
        substitutions.splice i, 1
        if new_word.endsWith("e") and not word.endsWith("e")
          substitutions.push
            suffix: "e"
            ending: ""

        recResult = rulesOfDetachment(new_word, substitutions)
        (if Array.isArray(recResult) == true
          result = result.concat(recResult)
        else
          result.push(recResult))
      i++
    result
  unless pos
    arr = [ "n", "v", "a", "r", "s" ]
    resArray = []
    i = 0
    while i <= 4
      resArray.push morphy(input_str, arr[i])
      i++
    reducedArray = []
    q = 0
    while q < resArray.length
      current = resArray[q]
      reducedArray.push current
      q++
    return _.flatten(reducedArray)
  substitutions = undefined
  switch pos
    when "n"
      substitutions = _.clone(MORPHY_SUBSTITUTIONS.NOUN)
    when "v"
      substitutions = _.clone(MORPHY_SUBSTITUTIONS.VERB)
    when "a"
      substitutions = _.clone(MORPHY_SUBSTITUTIONS.ADJECTIVE)
    else
      substitutions = []
  found_exceptions = []
  exception_morphs = EXCEPTIONS.map((elem) ->
    elem.morph
  )
  index = exception_morphs.indexOf(input_str)
  while index isnt -1
    if EXCEPTIONS[index].pos is pos
      base_word = new Word(EXCEPTIONS[index].lemma)
      base_word.part_of_speech = pos
      found_exceptions.push base_word
    index = exception_morphs.indexOf(input_str, index + 1)
  if found_exceptions.length > 0
    found_exceptions
  else
    if pos is "n" and input_str.endsWith("ful")
      suffix = "ful"
      input_str = input_str.slice(0, input_str.length - suffix.length)
    else
      suffix = ""
    rulesOfDetachment input_str, substitutions

module.exports = exports = memoize morphy
