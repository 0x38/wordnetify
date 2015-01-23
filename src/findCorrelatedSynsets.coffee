util = require 'util'
fs = require 'fs'
_ = require 'underscore'
require 'plus_arrays'
ProgressBar   = require 'progress'


###
returns all possible n choose 2 pairs from input array @arr
###
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

##
calculate the mutual information between the two supplied synsets, defined as
∑x ∑y log(p(x,y) / p(x) p(y)) p(x,y)
##
calculateMutualInformation = (synset1, synset2, nDocs) ->
  nCommon = _.intersection(synset1.docs, synset2.docs).length
  joint_prob = [(nDocs - nCommon) / nDocs, nCommon / nDocs]
  synset1_prob = [
    (nDocs - synset1.docs.length) / nDocs,
    synset1.docs.length / nDocs
  ]
  synset2_prob = [
    (nDocs - synset2.docs.length) / nDocs,
    synset2.docs.length / nDocs
  ]
  mutualInfo = 0
  for i in [0,1]
    mutualInfo += joint_prob[i] * (Math.log(Math.max(joint_prob[i], 0.0001) / (synset1_prob[i] * synset2_prob[i])))
  return mutualInfo

###
given wordnetify @output and @synsetid, finds the mutual information
with all other synsets with which it does not share corpus words, i.e. which
are in no ancestral relationship to the synset with id @synsetid
###
findCorrelatedSynsetsWithId = (output, synsetid) ->
  tree = output.tree
  nDocs = output.corpus.length
  nSynsets = Object.keys(output.tree).length
  synset1 = tree[synsetid]

  all_relevant_synsets = _.filter(tree, (val, key) ->
    if val.isCandidate == true then true else false
  )

  candidates = []
  progressCorrelation = new ProgressBar(
    'Calculate correlations [:bar] :percent :etas',
    { total: all_relevant_synsets.length }
  )
  for synset2, index in all_relevant_synsets
    common = _.intersection(
      Object.keys(synset2.words),
      Object.keys(synset1.words)
    )
    if synset2.docs.containsAny(synset1.docs) and common.length == 0
      o = {}
      o.mutualInfo = calculateMutualInformation(synset1, synset2, nDocs)
      o.synset2 = synset2.data.words.map( (e) -> e.lemma).splice(0, 3)
      candidates.push(o)
    progressCorrelation.tick()

  console.log "#{candidates.length} relevant correlated synsets identified"
  sorted_candidates = _.sortBy(candidates, (o) -> o.mutualInfo).reverse()
  return sorted_candidates

###
for wordnetify output object, finds all pairwise-correlated synsets
and returns those with largest mutual information
###
findCorrelatedSynsets = (output) ->
  tree = output.tree
  nDocs = output.corpus.lengt
  nSynsets = Object.keys(output.tree).length

  all_relevant_keys = _.filter(tree, (val, key) ->
    if val.isCandidate == true then true else false
  )
  all_pairs = pairs(all_relevant_keys)
  progressCorrelation = new ProgressBar(
    'Calculate correlations [:bar] :percent :etas', { total: all_pairs.length }
  )
  candidates = []
  maxMutualInfo = []
  for pair, index in all_pairs
    synset1 = pair[0]
    synset2 = pair[1]
    common = _.intersection(
      Object.keys(synset2.words), Object.keys(synset1.words)
    )
    if synset2.docs.containsAny(synset1.docs) and common.length == 0
      o = {}
      mi = calculateMutualInformation(synset1, synset2, nDocs)
      maxMutualInfo.push(mi)
      if (mi > maxMutualInfo.mean() * 2)
        o.mutualInfo = mi
        o.synset1 = synset1.data.words.map( (e) -> e.lemma ).splice(0, 3)
        o.synset2 = synset2.data.words.map( (e) -> e.lemma ).splice(0, 3)
        candidates.push(o)
    progressCorrelation.tick()

  console.log "#{candidates.length} relevant synset pairs identified"
  return _.sortBy(candidates, (o) -> o.mutualInfo).reverse()

module.exports = exports = {
  findCorrelatedSynsets: findCorrelatedSynsets,
  findCorrelatedSynsetsWithId: findCorrelatedSynsetsWithId
}
