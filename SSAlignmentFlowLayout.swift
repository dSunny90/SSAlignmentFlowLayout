//
//  SSAlignmentFlowLayout.swift
//  Common - CollectionViewLayout
//
//  Created by iSunSoo on 2017/11/01.
//  Copyright © 2017 SSG.COM. All rights reserved.
//

import UIKit

private let FLOATVAL_NOT_DEFINED: CGFloat = -9999
enum SSAlignmentType: String {
    // Vertical
    case left
    case center
    case right
    // Horizontal
    case top
    case middle
    case bottom
}

class SSAlignmentFlowLayout: UICollectionViewFlowLayout {
    /// 이 값을 XIB 상에서 주면 모든 섹션에서 같은 정렬대로 보여준다. alignment 는 read-only 로만 관리한다.
    @IBInspectable open var alignmentRawValue: String {
        get {
            return alignment.rawValue
        }
        set {
            guard let type = AlignmentType(rawValue: newValue) else {
                assertionFailure("alignmentRawValue is wrong value.")
                return
            }
            self.alignment = type
        }
    }
    var alignment: AlignmentType = .left

    // 이 FlowLayout을 그려주기 위한 Wrapper를 보관하며, 각 섹션에서 iteration 목적으로 사용
    private var sectionElements: [FixedSpacingSectionElement] = []
    // layoutAttributesForItem에서 hash할 key로 사용하기 위해 dictionary로 선언함
    private var cellAttrCacheDic: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var attrCache: [UICollectionViewLayoutAttributes] = []

    // prepareLayout에서는 layoutAttributes를 관리하기 위해 elements, attrCache를 초기화 후 생성함
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        sectionElements = []

        cellAttrCacheDic = [IndexPath: UICollectionViewLayoutAttributes]()
        attrCache.removeAll()

        for section in 0..<collectionView.numberOfSections {
            /// attribute가 최대로 배치될 수 있는 경계값 체크를 위함
            var thresholdValue: CGFloat = scrollDirection == .vertical ? collectionView.frame.width : collectionView.frame.height
            /// attribute가 배치될 현재 라인
            var currentLine: Int = 0
            /// 현재 라인에서의 attribute의 순서
            var currentOrder: Int = 0
            /// 라인에서의 시작 offset 보관용
            var currentOffset: CGFloat = 0

            // UICollectionViewDelegateFlowLayout 를 받은 경우 해당 값으로 고정(adapter 사용하는 경우 delegate는 self)
            // 값이 없는 경우(adapter 사용X)는 protocol 구현 없이 고정 값을 layout에 넣은 경우이다. (DEFAULT)
            let sectionElement = self.createSectionElement(section: section, collectionView: collectionView)

            // 한 줄에 최대로 채울 수 있는 한계값(threshold). scroll 방향에 따라 초기값을 분기함.
            if scrollDirection == .vertical {
                thresholdValue -= sectionElement.sectionInset.left
                thresholdValue -= sectionElement.sectionInset.right
            }
            else {
                thresholdValue -= sectionElement.sectionInset.top
                thresholdValue -= sectionElement.sectionInset.bottom
            }
            for row in 0..<collectionView.numberOfItems(inSection: section) {
                var itemSize: CGSize = .zero
                var itemSizeValue: CGFloat = 0
                if let delegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout,
                   let sizeForItemAt = delegate.collectionView?(collectionView, layout: self, sizeForItemAt: IndexPath(row: row, section: section)) {
                    itemSize = sizeForItemAt
                    itemSizeValue += (scrollDirection == .vertical) ? sizeForItemAt.width : sizeForItemAt.height
                }
                // 다음 아이템이 배치될 offset 계산
                var offset = currentOffset + itemSizeValue

                if currentOrder > 0 {
                    offset += sectionElement.fixedInteritemSpacing
                    // 간격을 추가하려 했으나, 초과하는 경우 다음 라인에 배치하고 순서 초기화
                    if offset > thresholdValue {
                        currentLine += 1
                        currentOrder = 0
                        offset = itemSizeValue
                    }
                }
                currentOffset = offset
                currentOrder += 1

                let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(row: row, section: section))
                layoutAttributes.frame = CGRect(x: 0, y: 0, width: itemSize.width, height: itemSize.height)
                if currentLine < sectionElement.lines.count {
                    sectionElement.lines[currentLine].items.append(layoutAttributes)
                    attrCache.append(layoutAttributes)
                }
                else {
                    // 이 attr로 라인이 시작되므로 라인을 추가해줘야 한다.
                    // spanSize Full인 경우 sectioninset 무시한 크기를 갖는다.
                    // 줄바꿈 처리를 했음에도 사이즈가 넘어가는 경우에 해당 셀의 사이즈를 줄여준다
                    var rect = layoutAttributes.frame
                    if scrollDirection == .vertical && rect.maxX > collectionView.frame.width - sectionElement.sectionInset.right {
                        rect.size.width = collectionView.frame.width - sectionElement.sectionInset.left - sectionElement.sectionInset.right
                        layoutAttributes.frame = rect
                    }
                    else if scrollDirection == .horizontal && rect.maxY > collectionView.frame.height - sectionElement.sectionInset.bottom {
                        rect.size.height = collectionView.frame.height - sectionElement.sectionInset.top - sectionElement.sectionInset.bottom
                        layoutAttributes.frame = rect
                    }
                    let lineElement = FixedSpacingLineElement()
                    lineElement.alignment = sectionElement.alignment
                    lineElement.itemSpacing = sectionElement.fixedInteritemSpacing
                    lineElement.items.append(layoutAttributes)
                    attrCache.append(layoutAttributes)
                    lineElement.fixedSizeValue = thresholdValue
                    sectionElement.lines.append(lineElement)
                }
                // 현재 라인을 채운 영역을 미리 저장
                sectionElement.lines[currentLine].totalMargin = thresholdValue - currentOffset
                sectionElement.lines[currentLine].sectionInset = sectionElement.sectionInset

                cellAttrCacheDic[IndexPath(row: row, section: section)] = layoutAttributes
            }

            // Supplementary View
            if let delegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
                // iOS 하위 버전에서 Supplementary View 와 관련된 bug가 많이 제보되어 헤더/푸터가 있는 경우를 나눠서 반드시 검사한다.
                var hasHeader: Bool = false
                var hasFooter: Bool = false
                if headerReferenceSize.width > 0, headerReferenceSize.height > 0 {
                    sectionElement.headerReferenceSize = headerReferenceSize
                    hasHeader = true
                }
                else if let headerSize = delegate.collectionView?(collectionView, layout: self, referenceSizeForHeaderInSection: section),
                   headerSize.width > 0, headerSize.height > 0 {
                    sectionElement.headerReferenceSize = headerSize
                    hasHeader = true
                }
                if footerReferenceSize.width > 0, footerReferenceSize.height > 0 {
                    sectionElement.footerReferenceSize = footerReferenceSize
                    hasFooter = true
                }
                else if let footerSize = delegate.collectionView?(collectionView, layout: self, referenceSizeForFooterInSection: section),
                   footerSize.width > 0, footerSize.height > 0 {
                    sectionElement.footerReferenceSize = footerSize
                    hasFooter = true
                }
                if hasHeader {
                    let headerAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, with: IndexPath(row: 0, section: section))
                    sectionElement.header = headerAttr
                    attrCache.append(headerAttr)
                }
                if hasFooter {
                    let footerAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, with: IndexPath(row: 0, section: section))
                    sectionElement.footer = footerAttr
                    attrCache.append(footerAttr)
                }
            }
            sectionElements.append(sectionElement)
        }

        attrCache = prefetchAllItems()
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        super.layoutAttributesForElements(in: rect)
        var visibleAttrs: [UICollectionViewLayoutAttributes] = []
        for attr in attrCache {
            if attr.frame.intersects(rect) {
                visibleAttrs.append(attr)
            }
        }
        return visibleAttrs
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if let attr = cellAttrCacheDic[indexPath] {
            return attr
        }
        else {
            return nil
        }
    }

    override var collectionViewContentSize: CGSize {
        if scrollDirection == .vertical {
            let height: CGFloat = sectionElements.reduce(0) { result, section in
                return result + section.sectionSize.height
            }
            return CGSize(width: collectionView?.frame.width ?? 0.0, height: height)
        }
        else {
            let width: CGFloat = sectionElements.reduce(0) { result, section in
                return result + section.sectionSize.width
            }
            return CGSize(width: width, height: collectionView?.frame.height ?? 0.0)
        }
    }

    private func prefetchAllItems() -> [UICollectionViewLayoutAttributes] {
        guard let collectionView else { return [] }
        var attrs: [UICollectionViewLayoutAttributes] = []
        var offset: CGFloat = 0
        for sectionElement in sectionElements {
            offset = sectionElement.locateHeader(offset: offset)
            var fixedSizeValue: CGFloat = 0
            switch sectionElement.alignment {
            case .left, .center, .right:
                fixedSizeValue = collectionView.frame.size.width
            case .top, .middle, .bottom:
                fixedSizeValue = collectionView.frame.size.height
            }
            offset = sectionElement.locateLines(fixedSize: fixedSizeValue, offset: offset)
            offset = sectionElement.locateFooter(offset: offset)
            attrs += sectionElement.attrs
            if let headerAttr = sectionElement.header {
                attrs.append(headerAttr)
            }
            if let footerAttr = sectionElement.footer {
                attrs.append(footerAttr)
            }
        }
        return attrs
    }

    private func createSectionElement(section: Int, collectionView: UICollectionView) -> FixedSpacingSectionElement {
        let sectionElement = FixedSpacingSectionElement()
        let delegateFlowLayout = collectionView.delegate as? UICollectionViewDelegateFlowLayout
        // section inset
        if let flowLayoutInset = delegateFlowLayout?.collectionView?(collectionView, layout: self, insetForSectionAt: section) {
            sectionElement.sectionInset = flowLayoutInset
        }
        else {
            sectionElement.sectionInset = sectionInset
        }
        // line spacing
        if let flowLayoutLine = delegateFlowLayout?.collectionView?(collectionView, layout: self, minimumLineSpacingForSectionAt: section) {
            sectionElement.fixedLineSpacing = flowLayoutLine
        }
        else {
            sectionElement.fixedLineSpacing = minimumLineSpacing
        }
        // item spacing
        if let flowLayoutInterItem = delegateFlowLayout?.collectionView?(collectionView, layout: self, minimumInteritemSpacingForSectionAt: section) {
            sectionElement.fixedInteritemSpacing = flowLayoutInterItem
        }
        else {
            sectionElement.fixedInteritemSpacing = minimumInteritemSpacing
        }
        // alignment
        sectionElement.alignment = alignment

        return sectionElement
    }
}

fileprivate class FixedSpacingSectionElement {
    var header: UICollectionViewLayoutAttributes?
    var footer: UICollectionViewLayoutAttributes?
    var lines: [FixedSpacingLineElement] = []
    var attrs: [UICollectionViewLayoutAttributes] = []
    var cellsRect: CGRect = .zero
    var sectionSize: CGSize {
        get {
            switch alignment {
            case .left, .center, .right:
                return CGSize(width: cellsRect.width,
                              height: headerReferenceSize.height + cellsRect.height + footerReferenceSize.height)
            case .top, .middle, .bottom:
                return CGSize(width: headerReferenceSize.width + cellsRect.width + footerReferenceSize.width,
                              height: cellsRect.height)
            }
        }
    }
    // CollectionView 제공
    var sectionInset: UIEdgeInsets = .zero
    var fixedLineSpacing: CGFloat = 0
    var fixedInteritemSpacing: CGFloat = 0
    var headerReferenceSize: CGSize = .zero
    var footerReferenceSize: CGSize = .zero
    /// 정렬 타입
    var alignment: AlignmentType = .left

    // MARK: - header, footer, cells frame 세팅

    // @param offset: Section 시작되는 frame의 offset
    // @return: header의 maxX/Y 값
    func locateHeader(offset: CGFloat) -> CGFloat {
        switch alignment {
        case .left, .center, .right:
            header?.frame = CGRect(x: 0, y: offset, width: headerReferenceSize.width, height: headerReferenceSize.height)
            return offset + headerReferenceSize.height
        case .top, .middle, .bottom:
            header?.frame = CGRect(x: offset, y: 0, width: headerReferenceSize.width, height: headerReferenceSize.height)
            return offset + headerReferenceSize.width
        }
    }

    // @param offset: 해당 section의 가장 마지막 cells frame의 maxX/Y + right/bottom
    // @return: footer의 maxX/Y 값
    func locateFooter(offset: CGFloat) -> CGFloat {
        switch alignment {
        case .left, .center, .right:
            footer?.frame = CGRect(x: 0, y: offset, width: footerReferenceSize.width, height: footerReferenceSize.height)
            return offset + footerReferenceSize.height
        case .top, .middle, .bottom:
            footer?.frame = CGRect(x: offset, y: 0, width: footerReferenceSize.width, height: footerReferenceSize.height)
            return offset + footerReferenceSize.width
        }
    }

    // @param fixedSize: 고정되는 영역(컬렉션뷰 width or height)
    // @param offset: Section 시작되는 frame의 offset
    // @return: 현재 섹션의 maxY 값
    func locateLines(fixedSize: CGFloat, offset: CGFloat) -> CGFloat {
        /// 줄 쩨한이 있는 경우에만
        var lineIndex: Int = 0
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        switch alignment {
        case .left, .center, .right:
            xOffset = sectionInset.left
            yOffset = offset + sectionInset.top
        case .top, .middle, .bottom:
            xOffset = offset + sectionInset.left
            yOffset = sectionInset.top
        }
        for line in lines {
            attrs += line.locateItems(xOffset: xOffset, yOffset: yOffset)
            switch alignment {
            case .left, .center, .right:
                yOffset += (line.maxSizeValue + fixedLineSpacing)
            case .top, .middle, .bottom:
                xOffset += (line.maxSizeValue + fixedLineSpacing)
            }
            lineIndex += 1
        }
        switch alignment {
        case .left, .center, .right:
            let attrsMaxY: CGFloat = attrs.map { $0.frame.maxY }.max() ?? 0
            cellsRect = CGRect(x: 0, y: offset, width: fixedSize, height: sectionInset.bottom + attrsMaxY - offset)
            return offset + cellsRect.height
        case .top, .middle, .bottom:
            let attrsMaxX: CGFloat = attrs.map { $0.frame.maxX }.max() ?? 0
            cellsRect = CGRect(x: offset, y: 0, width: sectionInset.right + attrsMaxX - offset, height: fixedSize)
            return offset + cellsRect.width
        }
    }
}

fileprivate class FixedSpacingLineElement {
    var alignment: AlignmentType = .left
    var itemSpacing: CGFloat = 0
    var totalMargin: CGFloat = FLOATVAL_NOT_DEFINED
    var sectionInset: UIEdgeInsets = .zero
    var fixedSizeValue: CGFloat = 0
    var maxSizeValue: CGFloat {
        get {
            switch alignment {
            case .left, .center, .right:
                return items.map { $0.size.height }.max() ?? 0
            case .top, .middle, .bottom:
                return items.map { $0.size.width }.max() ?? 0
            }
        }
    }
    var startingOffset: CGFloat {
        get {
            switch alignment {
            case .left, .top:
                return 0
            case .center, .middle:
                return totalMargin / 2
            case .right, .bottom:
                return totalMargin
            }
        }
    }
    var items: [UICollectionViewLayoutAttributes] = []

    func locateItems(xOffset: CGFloat, yOffset: CGFloat) -> [UICollectionViewLayoutAttributes] {
        var attrs: [UICollectionViewLayoutAttributes] = []
        var xPos: CGFloat = xOffset
        var yPos: CGFloat = yOffset
        // offset 초기화
        switch alignment {
        case .left, .center, .right:
            xPos = sectionInset.left + startingOffset
        case .top, .middle, .bottom:
            yPos = sectionInset.top + startingOffset
        }
        // 각 attribute들 x, y값 새로 지정하여 보관한다.
        for item in items {
            let attr = UICollectionViewLayoutAttributes(forCellWith: item.indexPath)
            attr.frame = CGRect(x: xPos, y: yPos, width: item.size.width, height: item.size.height)
            switch alignment {
            case .left, .center, .right:
                xPos += (item.size.width + itemSpacing)
            case .top, .middle, .bottom:
                yPos += (item.size.height + itemSpacing)
            }
            attrs.append(attr)
        }
        return attrs
    }
}
