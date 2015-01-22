util = require 'util'
fs = require 'fs'
_ = require 'underscore'
require 'plus_arrays'
ProgressBar   = require 'progress'

pairs = (arr) ->
  res = []
  l = arr.length
  i = 0
  while i < l
    j = i + 1
    while j < l
      res.push [
        arr[i]
        arr[j]
      ]
      ++j
    ++i
  return res

calculateMutualInformation = (synset1, synset2, nDocs) ->
  nCommon = _.intersection(synset1.docs, synset2.docs).length
  joint_prob = [(nDocs - nCommon) / nDocs, nCommon / nDocs]
  synset1_prob = [(nDocs - synset1.docs.length) / nDocs, synset1.docs.length / nDocs]
  synset2_prob = [(nDocs - synset2.docs.length) / nDocs, synset2.docs.length / nDocs]
  mutualInfo = 0
  for i in [0,1]
    mutualInfo += joint_prob[i] * (Math.log(Math.max(joint_prob[i], 0.0001) / (synset1_prob[i] * synset2_prob[i])))
  return mutualInfo

findCorrelatedSynsetsWithId = (output, synsetid) ->
  tree = output.tree
  nDocs = output.corpus.length
  nSynsets = Object.keys(output.tree).length
  synset1 = tree[synsetid]

  all_relevant_synsets = _.filter(tree, (val, key) =>
    if val.isCandidate == true then true else false
  )

  candidates = []
  progressCorrelation = new ProgressBar('Calculate correlations [:bar] :percent :etas', { total: all_relevant_synsets.length })
  for synset2, index in all_relevant_synsets
    if synset2.docs.containsAny(synset1.docs) and _.intersection(Object.keys(synset2.words), Object.keys(synset1.words)).length == 0
      o = {}
      o.mutualInfo = calculateMutualInformation(synset1, synset2, nDocs)
      o.synset2 = synset2.data.words.map((e)=>e.lemma).splice(0,3)
      candidates.push(o)
    progressCorrelation.tick()

  console.log "#{candidates.length} relevant correlated synsets identified"
  sorted_candidates = _.sortBy(candidates, (o) => o.mutualInfo).reverse()
  return sorted_candidates

findCorrelatedSynsets = (output) ->


module.exports = {findCorrelatedSynsets: findCorrelatedSynsets, findCorrelatedSynsetsWithId: findCorrelatedSynsetsWithId}
