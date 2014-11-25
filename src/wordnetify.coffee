`#!/usr/bin/env node`

program   = require 'commander'
fs        = require 'fs'
csv       = require 'csv'
mime      = require 'mime'
BPromise  = require 'bluebird'
util      = require 'util'

{ getCorpusSynsets }            = require "./synsetRepresentation"
{ constructSynsetData }         = require "./constructSynsetData"
pickSynsets                     = require "./pickSynsets"
{ generateCorpusTree, generateWordTree } = require "./treeGenerator"
thresholdTree                   = require "./thresholdTree"
calculateCounts                 = require "./counting"
{ thresholdDocTree, thresholdWordTree } = require "./thresholdTree"

createWordNetTree = (corpus) ->
    console.time "Step 1: Retrieve Synset Data"
    wordTreshold = if program.threshold then program.threshold else  1
    synsetArray = getCorpusSynsets(corpus)
    BPromise.all(synsetArray).then () =>
      console.timeEnd "Step 1: Retrieve Synset Data"
      console.time "Step 2: Generate Candidate Sets"

    docTrees = synsetArray.map( (d, index) =>
      docTreeMsg = "Construct Candidate Set for Words of Doc " + index
      console.time(docTreeMsg)
      wordTrees = d.map( (w) => constructSynsetData(w, index) )
      BPromise.all(wordTrees).then console.timeEnd(docTreeMsg)
      return wordTrees.filter( (word) => word != null )
    )
    BPromise.all(docTrees).then () =>
      console.timeEnd "Step 2: Generate Candidate Sets"
      console.time "Step 3: Pruning (Word Sense Disambiguation)"
    fPrunedDocTrees = docTrees.filter( (doc) => doc != null).map( (doc) =>
      pickSynsets(doc)
    )
    BPromise.all(fPrunedDocTrees).then (prunedDocTrees) =>
      console.timeEnd("Step 3: Pruning (Word Sense Disambiguation)")
      outputJSON = ''

      if program.combine
        corpusTree = generateCorpusTree(prunedDocTrees)
        finalTree = calculateCounts(corpusTree)
        if program.threshold
          finalTree = thresholdDocTree(finalTree, program.threshold)
        ret = {}
        ret.tree = finalTree
        ret.corpus = corpus
        outputJSON = if program.pretty then JSON.stringify(ret, null, 2) else JSON.stringify(ret)
      else
        ret = prunedDocTrees.map((doc) => generateWordTree(doc))
                            .map( (doc) => calculateCounts(doc) )
        if program.threshold
          ret = ret.map( (tree) => thresholdWordTree(tree))

        outputJSON = if program.pretty then JSON.stringify(ret, null, 2) else JSON.stringify(ret)

      if program.output
        fs.writeFileSync(program.output, outputJSON)
      else
        console.log(outputJSON)


###
Command-Line-Interface:
###

program
  .version('0.2.1')
  .option('-i, --input [value]', 'Load data from disk')
  .option('-l, --list <items>','A list of input texts')
  .option('-o, --output [value]', 'Write results to file')
  .option('-t, --threshold <n>', 'Threshold for Tree Nodes', parseInt)
  .option('-c, --combine','Merge document trees to form corpus tree')
  .option('-d, --delim [value]','Delimiter to split text into documents')
  .option('-p, --pretty','Pretty print of JSON output')
  .option('-v, --verbose','Print additional logging information')
  .parse(process.argv)

corpus;
delim = program.delim

if program.list
  delim = delim or ";"
  corpus = program.list.split(delim)
  createWordNetTree(corpus)
else if (program.input)
  data = fs.readFileSync(program.input)
  mime_type = mime.lookup(program.input)
  switch mime_type
    when "text/plain"
      delim = delim or "  "
      corpus = String(data).replace(/\r\n?/g, "\n").split(delim).clean("")
      createWordNetTree(corpus)
    when "text/csv"
      csv.parse(String(data), (err, output) =>
        corpus = output.map( (d) => d[0] )
        createWordNetTree(corpus)
      )
