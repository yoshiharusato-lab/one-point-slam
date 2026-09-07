import { Controller } from "@hotwired/stimulus"

// トーナメント表(左右対称+中央決勝)のレイアウト計算と勝敗ラインの描画。
// 1枠には1人しか入らない。座標はすべて「枠(.player)の中心Y」で管理する。
const BOX_H = 34 // 選手1人ぶんの枠の高さ(CSSの .player の min-height と合わせる)
const SLOT_GAP = 10 // 1回戦で、同じ対戦カードの2枠の間隔
const MATCH_GAP = 26 // 1回戦で、対戦カード同士の間隔

export default class extends Controller {
  static targets = ["bracket", "lines"]

  connect() {
    this.alignAndDraw = this.alignAndDraw.bind(this)
    this.alignAndDraw()
    requestAnimationFrame(this.alignAndDraw)
    window.addEventListener("resize", this.alignAndDraw)
  }

  disconnect() {
    window.removeEventListener("resize", this.alignAndDraw)
  }

  alignAndDraw() {
    if (!this.hasBracketTarget) return

    this.positionAllRoundMatches()
    this.fitBracketScale()
    this.drawBracketLines()
  }

  getRounds(side) {
    return Array.from(this.bracketTarget.querySelectorAll(`.round[data-side="${side}"]`)).sort(
      (a, b) => parseInt(a.dataset.round, 10) - parseInt(b.dataset.round, 10)
    )
  }

  mergeY(boxPair) {
    return (boxPair[0] + boxPair[1]) / 2
  }

  // k個(前ラウンドの対戦カード数)を、隣り合った順番のまま m個(次のラウンドの
  // 対戦カード数)の枠へできるだけ均等に振り分ける(bracket_advancer.rb の
  // round1_groups と同じ考え方)。例えば k=7, m=4 なら [0,1]→枠0, [2,3]→枠1,
  // [4,5]→枠2, [6]→枠3。単純な余り(index % 枠数)で散らすと、盤面上で遠く
  // 離れた対戦カード同士が同じ枠に組み合わされ、対戦カードが引き伸ばされて
  // 線がどこに向かっているのか分からなくなる。
  roundGroups(k, m) {
    const groups = Array.from({ length: m }, () => [])
    for (let i = 0; i < k; i++) groups[Math.floor((i * m) / k)].push(i)
    return groups
  }

  // ボトムアップでの位置計算：
  // ラウンド0(1回戦)の枠は等間隔に並べ、それ以降の枠は「その枠に勝ち上がってくる
  // 対戦カード(子)の2枠の中間点」に置く。こうすると子の対戦カードから伸びる線が
  // まっすぐ親の枠に入り、シード(不戦勝)で試合数が2の累乗でなくてもズレない。
  layoutSide(rounds) {
    const boxYByRound = {}
    if (!rounds.length) return { boxYByRound, height: 0 }

    const unit = BOX_H * 2 + SLOT_GAP + MATCH_GAP
    const sortedRounds = [...rounds].sort((a, b) => parseInt(a.dataset.round, 10) - parseInt(b.dataset.round, 10))

    const round0 = sortedRounds[0]
    const leaf = round0.querySelectorAll(".matches > .match")
    const r0 = parseInt(round0.dataset.round, 10)
    boxYByRound[r0] = []
    leaf.forEach((_m, i) => {
      const topCenter = i * unit + MATCH_GAP / 2 + BOX_H / 2
      boxYByRound[r0].push([ topCenter, topCenter + BOX_H + SLOT_GAP ])
    })
    let height = leaf.length * unit

    for (let idx = 1; idx < sortedRounds.length; idx++) {
      const r = parseInt(sortedRounds[idx].dataset.round, 10)
      const prevR = parseInt(sortedRounds[idx - 1].dataset.round, 10)
      const childPairs = boxYByRound[prevR] || []
      const matches = sortedRounds[idx].querySelectorAll(".matches > .match")
      // connectSide と同じ判定: 1回戦はシードの人数次第で、前のラウンドの対戦カード数が
      // ちょうど2倍にならないことがある(例: 12人なら1回戦2試合・2回戦2試合)。その
      // 場合は bracket_advancer.rb の seat_round1_winners_on_side と同じ「隣り合った
      // 対戦カードごとにまとめる」対応関係で子の位置を探す。
      const useSpread = childPairs.length !== matches.length * 2
      const groups = useSpread ? this.roundGroups(childPairs.length, matches.length) : null
      boxYByRound[r] = []
      matches.forEach((_m, i) => {
        const ys = []
        if (useSpread) {
          const [ c0, c1 ] = groups[i]
          const child0 = childPairs[c0]
          const child1 = c1 !== undefined ? childPairs[c1] : undefined
          ys.push(child0 ? this.mergeY(child0) : height / 2)
          ys.push(child1 ? this.mergeY(child1) : ys[0] + BOX_H + SLOT_GAP)
        } else {
          for (let s = 0; s < 2; s++) {
            const child = childPairs[i * 2 + s]
            ys.push(child ? this.mergeY(child) : (ys[0] !== undefined ? ys[0] + BOX_H + SLOT_GAP : height / 2))
          }
        }
        boxYByRound[r].push(ys)
      })

      // シード同士の対戦カード(この側の前ラウンドに対応する試合が無い)は上の
      // フォールバック位置に置かれるため、他の対戦カード(子から計算した本来の位置)
      // と被ることがある。上から順に走査し、最低間隔(MATCH_GAP)を下回る場合だけ
      // 必要な分だけ下へずらして、対戦カード同士が重ならないようにする。
      let prevBottomEdge = -Infinity
      boxYByRound[r].forEach((pair) => {
        const topEdge = pair[0] - BOX_H / 2
        if (topEdge < prevBottomEdge + MATCH_GAP) {
          const shift = (prevBottomEdge + MATCH_GAP) - topEdge
          pair[0] += shift
          pair[1] += shift
        }
        prevBottomEdge = pair[1] + BOX_H / 2
      })

      const lastPair = boxYByRound[r][boxYByRound[r].length - 1]
      if (lastPair) height = Math.max(height, lastPair[1] + BOX_H / 2)
    }
    return { boxYByRound, height }
  }

  placeMatch(matchEl, topCenter, bottomCenter) {
    matchEl.style.top = `${topCenter - BOX_H / 2}px`
    matchEl.style.height = `${bottomCenter - topCenter + BOX_H}px`
  }

  // その側の最終ラウンド(=決勝に一番近いラウンド)の勝者が出てくるY(オフセット適用前の生の値)
  rawLastRoundMergeY(layout) {
    const keys = Object.keys(layout.boxYByRound).map(Number)
    if (!keys.length) return null
    const pairs = layout.boxYByRound[Math.max(...keys)]
    if (!pairs || !pairs.length) return null
    return (this.mergeY(pairs[0]) + this.mergeY(pairs[pairs.length - 1])) / 2
  }

  // 決勝の位置を先に固定し(全体の高さの中央)、左右それぞれのオフセットは
  // 「その側の最終ラウンドの中心が、決勝の対応する枠にぴったり合う」ように逆算する。
  // (以前は決勝側を左右の平均位置に置いていたため、どちらの準決勝からの線も
  //  決勝の枠の中心からズレることがあった)
  positionAllRoundMatches() {
    const left = this.getRounds("left")
    const right = this.getRounds("right")
    const centerRound = this.bracketTarget.querySelector('.round[data-side="center"]')

    this.bracketTarget.querySelectorAll(".match").forEach((m) => { m.style.transform = "" })

    const leftLayout = this.layoutSide(left)
    const rightLayout = this.layoutSide(right)
    let totalHeight = Math.max(leftLayout.height, rightLayout.height, BOX_H * 2 + SLOT_GAP)

    const half = (BOX_H + SLOT_GAP) / 2
    let finalCy = totalHeight / 2
    let leftTarget = finalCy - half
    let rightTarget = finalCy + half

    const rawLeftMerge = this.rawLastRoundMergeY(leftLayout)
    const rawRightMerge = this.rawLastRoundMergeY(rightLayout)

    let leftOffset = rawLeftMerge !== null ? leftTarget - rawLeftMerge : (totalHeight - leftLayout.height) / 2
    let rightOffset = rawRightMerge !== null ? rightTarget - rawRightMerge : (totalHeight - rightLayout.height) / 2

    // 決勝を固定したまま各サイドをずらすと、どちらかの側が上下にはみ出すことがあるので、
    // はみ出す分だけ全体(両サイド+決勝)を平行移動して高さを広げる。
    const extentTop = Math.min(0, leftOffset, rightOffset, leftTarget - BOX_H / 2)
    const extentBottom = Math.max(
      totalHeight,
      leftOffset + leftLayout.height,
      rightOffset + rightLayout.height,
      rightTarget + BOX_H / 2
    )
    const shift = -extentTop
    totalHeight = extentBottom - extentTop
    leftOffset += shift
    rightOffset += shift
    leftTarget += shift
    rightTarget += shift

    const applySide = (rounds, layout, offset) => {
      rounds.forEach((roundEl) => {
        const r = parseInt(roundEl.dataset.round, 10)
        const matchesEl = roundEl.querySelector(".matches")
        const matches = roundEl.querySelectorAll(".matches > .match")
        const pairs = layout.boxYByRound[r] || []
        matches.forEach((m, i) => {
          const pair = pairs[i] || (() => {
            const fallback = layout.height / 2
            return [ fallback, fallback + BOX_H + SLOT_GAP ]
          })()
          this.placeMatch(m, pair[0] + offset, pair[1] + offset)
        })
        if (matchesEl) matchesEl.style.height = `${totalHeight}px`
      })
    }
    applySide(left, leftLayout, leftOffset)
    applySide(right, rightLayout, rightOffset)

    if (centerRound) {
      const m = centerRound.querySelector(".matches > .match")
      const matchesEl = centerRound.querySelector(".matches")
      if (matchesEl) matchesEl.style.height = `${totalHeight}px`
      if (m) this.placeMatch(m, leftTarget, rightTarget)
    }

    return totalHeight
  }

  drawBracketLines() {
    if (!this.hasLinesTarget) return

    const svg = this.linesTarget
    while (svg.firstChild) svg.removeChild(svg.firstChild)

    const wrapRect = this.element.getBoundingClientRect()
    // 横スクロールで縮小率に下限をかけたトーナメント表がラップ幅より広がっている
    // ことがあるため、SVGの大きさは見えている範囲(wrapRect)ではなく、スクロール
    // 込みの全体幅(scrollWidth)に合わせる。そうしないとスクロールしないと見えない
    // 部分の接続線が描画エリア外になって消えてしまう。
    const svgWidth = Math.max(wrapRect.width, this.element.scrollWidth)
    const svgHeight = Math.max(wrapRect.height, this.element.scrollHeight)
    svg.setAttribute("width", svgWidth)
    svg.setAttribute("height", svgHeight)
    svg.style.width = `${svgWidth}px`
    svg.style.height = `${svgHeight}px`

    const centerMatch = this.bracketTarget.querySelector('.round[data-side="center"] .match')
    if (!centerMatch) return

    this.connectSide(svg, wrapRect, this.getRounds("left"), centerMatch, false)
    this.connectSide(svg, wrapRect, this.getRounds("right"), centerMatch, true)
  }

  connectSide(svg, wrapRect, rounds, finalMatch, mirrored) {
    for (let r = 0; r < rounds.length; r++) {
      const matches = rounds[r].querySelectorAll(".matches > .match")
      const isLast = r === rounds.length - 1
      const nextMatches = isLast ? null : rounds[r + 1].querySelectorAll(".matches > .match")
      // 1回戦はシード(不戦勝)の人数次第で、次のラウンドの対戦カード数がちょうど
      // 半分にならないことがある(例: 12人なら1回戦2試合・2回戦2試合)。その場合は
      // bracket_advancer.rb の seat_round1_winners_on_side と同じ「隣り合った対戦
      // カードごとにまとめる」対応関係で線を引く。
      const useSpread = !isLast && matches.length !== nextMatches.length * 2
      let reverseGroups = null
      if (useSpread) {
        reverseGroups = []
        this.roundGroups(matches.length, nextMatches.length).forEach((indices, matchIndex) => {
          indices.forEach((originIndex, slotIndex) => { reverseGroups[originIndex] = [ matchIndex, slotIndex ] })
        })
      }

      for (let i = 0; i < matches.length; i++) {
        let parentMatch, parentSlot
        if (isLast) {
          parentMatch = finalMatch
          parentSlot = mirrored ? 1 : 0
        } else if (useSpread) {
          const [ matchIndex, slotIndex ] = reverseGroups[i]
          parentMatch = nextMatches[matchIndex]
          parentSlot = slotIndex
        } else {
          parentMatch = nextMatches[Math.floor(i / 2)]
          parentSlot = i % 2
        }
        if (!parentMatch) continue

        const parentBox = parentMatch.querySelectorAll(".player")[parentSlot]
        if (!parentBox) continue

        this.connectMatch(svg, wrapRect, matches[i], parentBox, mirrored)
      }
    }
  }

  connectMatch(svg, wrapRect, matchEl, parentBox, mirrored) {
    const boxes = matchEl.querySelectorAll(".player")
    if (!boxes.length) return

    let winnerSlot = -1
    boxes.forEach((b, i) => { if (b.classList.contains("is-winner")) winnerSlot = i })

    const parentRect = parentBox.getBoundingClientRect()
    const parentY = parentRect.top + parentRect.height / 2 - wrapRect.top
    const parentX = (mirrored ? parentRect.right : parentRect.left) - wrapRect.left

    let startX = null
    const stubs = []
    boxes.forEach((b, i) => {
      const rect = b.getBoundingClientRect()
      const x = (mirrored ? rect.left : rect.right) - wrapRect.left
      if (startX === null || (mirrored ? x < startX : x > startX)) startX = x
      stubs.push({
        x,
        y: rect.top + rect.height / 2 - wrapRect.top,
        cls: winnerSlot === -1 ? "bracket-line-pending" : (i === winnerSlot ? "bracket-line-won" : "bracket-line-lost")
      })
    })

    const midX = startX + (parentX - startX) / 2
    const branchY = stubs.reduce((sum, s) => sum + s.y, 0) / stubs.length
    const outgoingClass = winnerSlot === -1 ? "bracket-line-pending" : "bracket-line-won"

    stubs.forEach((s) => {
      this.drawLine(svg, s.x, s.y, midX, s.y, s.cls)
      if (s.y !== branchY) this.drawLine(svg, midX, s.y, midX, branchY, s.cls)
    })

    if (branchY !== parentY) this.drawLine(svg, midX, branchY, midX, parentY, outgoingClass)
    this.drawLine(svg, midX, parentY, parentX, parentY, outgoingClass)
  }

  drawLine(svg, x1, y1, x2, y2, cls) {
    const ns = "http://www.w3.org/2000/svg"
    const line = document.createElementNS(ns, "line")
    line.setAttribute("x1", x1)
    line.setAttribute("y1", y1)
    line.setAttribute("x2", x2)
    line.setAttribute("y2", y2)
    line.setAttribute("class", `bracket-line ${cls}`)
    svg.appendChild(line)
  }

  // 画面幅に収まらないぶんを全部縮小すると、ラウンド数の多いトーナメントほど
  // スマホで文字が読めないほど小さくなってしまうため、縮小率に下限を設ける。
  // 下限を下回ってもまだ収まらない場合は、.tournament-bracket-wrap を横スクロール
  // させて見てもらう(CSS側で overflow-x: auto にしている)。
  MIN_SCALE = 0.65

  fitBracketScale() {
    const bracket = this.bracketTarget

    bracket.style.transform = ""
    void bracket.offsetWidth

    const wrapWidth = this.element.getBoundingClientRect().width || this.element.clientWidth
    const naturalWidth = bracket.scrollWidth
    const naturalHeight = bracket.scrollHeight

    const rawScale = wrapWidth > 0 && naturalWidth > wrapWidth ? wrapWidth / naturalWidth : 1
    const scale = Math.max(rawScale, this.MIN_SCALE)
    bracket.style.transform = `scale(${scale})`

    const visualHeight = naturalHeight * scale
    this.element.style.height = `${visualHeight + 40}px`
  }
}
