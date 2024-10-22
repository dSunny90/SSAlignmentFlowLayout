//
//  SSAlignmentFlowLayout.swift
//  SSAlignmentFlowLayout
//
//  Created by SunSoo Jeon on 01.11.2017.
//
//  HISTORY
//  2017.11.01. Initially developed in Objective-C
//  2018.09.12. Converted to Swift
//  2021.02.24. Bug fixes applied
//  2024.06.23. Refactoring - Alignment by section
//  2024.10.22. Refactoring - Caches and naming
//

import UIKit

public final class SSAlignmentFlowLayout: UICollectionViewFlowLayout {
    /// Provides per-section alignment when initialized with `alignmentProvider`.
    public typealias SectionAlignmentProvider = (_ section: Int) -> Alignment
    /// Provides per-section limitOfRows when initialized with `limitOfRowsProvider`.
    public typealias LimitOfRowsProvider = (_ section: Int) -> Int

    fileprivate let kHeader = UICollectionView.elementKindSectionHeader
    fileprivate let kFooter = UICollectionView.elementKindSectionFooter

    /// Defines the alignment for all sections when set via XIB or during initialization.
    /// This property updates the internal `alignment` value accordingly.
    @IBInspectable public var alignmentRawValue: String {
        get {
            return alignment.rawValue
        }
        set {
            guard let type = Alignment(rawValue: newValue) else {
                assertionFailure("alignmentRawValue is wrong value.")
                return
            }
            self.alignment = type
        }
    }
    /// The current alignment type used by the flow layout (default is `.left`).
    internal var alignment: Alignment = .left
    /// The maximum number of rows allowed per section (0 means unlimited).
    @IBInspectable public var limitOfRows: Int = 0

    /// Closure to determine alignment for each section.
    internal var alignmentProvider: SectionAlignmentProvider?
    /// Provides row limit per section. If nil, uses `limitOfRows`.
    internal var limitOfRowsProvider: LimitOfRowsProvider?

    /// Stores layout metadata for each section, used during layout calculations.
    private var sectionElements: [FixedSpacingSectionElement] = []

    private var cellCache: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var supplementaryViewCache: [String: [IndexPath: UICollectionViewLayoutAttributes]] = [
        UICollectionView.elementKindSectionHeader: [:],
        UICollectionView.elementKindSectionFooter: [:]
    ]

    public override init() {
        super.init()
    }

    /// A convenience initializer for defining section-based alignment
    /// and row limits.
    ///
    /// - Parameters:
    ///   - alignment: A default alignment (`.left`, `.center`, `.right`)
    ///     applied to all sections. Ignored if `alignmentProvider` is provided.
    ///   - limitOfRows: Default row limit for each section. `0` means no limit.
    ///     Ignored if `limitOfRowsProvider` is provided.
    ///   - alignmentProvider: Optional closure to provide custom alignment
    ///     per section. If provided, this overrides the default `alignment`.
    ///   - limitOfRowsProvider: Optional closure to provide custom row limits
    ///     per section. If provided, this overrides the default `limitOfRows`.
    ///
    /// - Note:
    ///   ⚠️ Be careful when referencing `self` inside these closures:
    ///   capture `self` weakly to avoid retain cycles.
    ///
    ///   Example:
    ///   ```swift
    ///   self.collectionView.collectionViewLayout = { [weak self] section in
    ///       guard let self else { return }
    ///       return self.alignment(for: section)
    ///   }
    ///   ```
    public convenience init(
        alignment: Alignment = .left,
        alignmentProvider: SectionAlignmentProvider? = nil,
        limitOfRows: Int = 0,
        limitOfRowsProvider: LimitOfRowsProvider? = nil
    ) {
        self.init()
        self.alignment = alignment
        self.limitOfRows = limitOfRows
        self.alignmentProvider = alignmentProvider
        self.limitOfRowsProvider = limitOfRowsProvider
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func prepare() {
        super.prepare()
        guard let collectionView else { return }

        sectionElements = []
        resetCaches()

        for section in 0..<collectionView.numberOfSections {
            buildAttributes(for: section, in: collectionView)
        }
        prefetchAllItems()
    }

    public override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        var visibleAttributes: [UICollectionViewLayoutAttributes] = []

        for attr in cellCache.values where attr.frame.intersects(rect) {
            visibleAttributes.append(attr)
        }
        for dict in supplementaryViewCache.values {
            for attr in dict.values where attr.frame.intersects(rect) {
                visibleAttributes.append(attr)
            }
        }

        return visibleAttributes
    }

    public override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        return cellCache[indexPath]
    }

    public override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        if scrollDirection == .vertical {
            let height: CGFloat = sectionElements.reduce(0) { result, section in
                return result + section.sectionSize.height
            }
            return CGSize(width: collectionView.frame.width, height: height)
        }
        else {
            let width: CGFloat = sectionElements.reduce(0) { result, section in
                return result + section.sectionSize.width
            }
            return CGSize(width: width, height: collectionView.frame.height)
        }
    }

    private func resetCaches() {
        cellCache.removeAll(keepingCapacity: true)
        supplementaryViewCache = [ kHeader: [:], kFooter: [:] ]
    }

    /// Validates the given alignment based on the current scroll direction.
    /// - If the alignment is incompatible with the scroll direction (e.g., `.top` in vertical mode),
    ///   it returns a default valid alignment (`.left` for vertical, `.top` for horizontal).
    /// - In DEBUG mode, an assertion failure is triggered to help catch incorrect usage.
    ///
    /// - Parameter alignment: The alignment value to validate.
    /// - Returns: A valid alignment adjusted to match the current scroll direction.
    private func validateAlignment(_ alignment: Alignment) -> Alignment {
        switch scrollDirection {
        case .vertical:
            if alignment == .top {
                #if DEBUG
                assertionFailure("Invalid alignment \(alignment) for vertical scroll. Fallback to .left")
                #endif
                return .left
            } else if alignment == .middle {
                #if DEBUG
                assertionFailure("Invalid alignment \(alignment) for vertical scroll. Fallback to .center")
                #endif
                return .center
            } else if alignment == .bottom {
                #if DEBUG
                assertionFailure("Invalid alignment \(alignment) for vertical scroll. Fallback to .right")
                #endif
                return .right
            } else {
                return alignment
            }
        case .horizontal:
            if alignment == .left {
                #if DEBUG
                assertionFailure("Invalid alignment \(alignment) for horizontal scroll. Fallback to .top")
                #endif
                return .top
            } else if alignment == .center {
                #if DEBUG
                assertionFailure("Invalid alignment \(alignment) for horizontal scroll. Fallback to .middle")
                #endif
                return .middle
            } else if alignment == .right {
                #if DEBUG
                assertionFailure("Invalid alignment \(alignment) for horizontal scroll. Fallback to .bottom")
                #endif
                return .bottom
            } else {
                return alignment
            }
        @unknown default:
            return alignment
        }
    }

    /// Builds layout attributes for a specific section in the collection view.
    /// This method configures line capacity based on scroll direction, calculates
    /// item placement, and sets up supplementary views (header and footer).
    ///
    /// - Parameters:
    ///   - section: The index of the section to build attributes for.
    ///   - collectionView: The collection view where the layout is applied.
    private func buildAttributes(
        for section: Int, in collectionView: UICollectionView
    ) {
        let delegate: UICollectionViewDelegateFlowLayout?
        if let aDelegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
            delegate = aDelegate
        } else {
            delegate = nil
        }
        // Create a section element that stores layout information
        let sectionElement = self.createSectionElement(
            section: section, collectionView: collectionView
        )
        // Calculate the maximum line capacity (width or height available for items)
        // based on the scroll direction and section insets.
        let lineCapacity: CGFloat
        switch scrollDirection {
        case .vertical:
            lineCapacity = collectionView.frame.width
                - sectionElement.sectionInset.left
                - sectionElement.sectionInset.right
        case .horizontal:
            lineCapacity = collectionView.frame.height
                - sectionElement.sectionInset.top
                - sectionElement.sectionInset.bottom
        @unknown default:
            lineCapacity = collectionView.frame.width
                - sectionElement.sectionInset.left
                - sectionElement.sectionInset.right
        }
        // Calculate item positions and line breaks for this section.
        calculateLineBreaks(
            for: section,
            in: collectionView,
            sectionElement: sectionElement,
            lineCapacity: lineCapacity
        )

        // Determine the header size, prioritizing fixed `headerReferenceSize` if provided.
        let headerSize = headerReferenceSize.width > 0 && headerReferenceSize.height > 0
            ? headerReferenceSize
            : (delegate?.collectionView?(
                collectionView,
                layout: self,
                referenceSizeForHeaderInSection: section
            ) ?? .zero)
        // Determine the footer size, prioritizing fixed `footerReferenceSize` if provided.
        let footerSize = footerReferenceSize.width > 0 && footerReferenceSize.height > 0
            ? footerReferenceSize
            : (delegate?.collectionView?(
                collectionView,
                layout: self,
                referenceSizeForFooterInSection: section
            ) ?? .zero)

        let hasHeader = headerSize.width > 0 && headerSize.height > 0
        let hasFooter = footerSize.width > 0 && footerSize.height > 0

        let viewIndexPath: IndexPath = IndexPath(row: 0, section: section)
        // If header exists, create its layout attributes and cache it.
        if hasHeader {
            sectionElement.headerReferenceSize = headerSize
            let headerAttr = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                with: viewIndexPath)
            sectionElement.headerLayoutAttrributes = headerAttr
            supplementaryViewCache[kHeader]?[viewIndexPath] = headerAttr
        }
        // If footer exists, create its layout attributes and cache it.
        if hasFooter {
            sectionElement.footerReferenceSize = footerSize
            let footerAttr = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                with: viewIndexPath)
            sectionElement.footerLayoutAttrributes = footerAttr
            supplementaryViewCache[kFooter]?[viewIndexPath] = footerAttr
        }
        // Append section element if it has header/footer or contains any items.
        if hasHeader
            || hasFooter
            || collectionView.numberOfItems(inSection: section) > 0
        {
            sectionElements.append(sectionElement)
        }
    }

    private func calculateLineBreaks(
        for section: Int,
        in collectionView: UICollectionView,
        sectionElement: FixedSpacingSectionElement,
        lineCapacity: CGFloat
    ) {
        let delegate: UICollectionViewDelegateFlowLayout?
        if let aDelegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
            delegate = aDelegate
        } else {
            delegate = nil
        }

        let numberOfItems = collectionView.numberOfItems(inSection: section)
        var line: Int = 0
        var order: Int = 0
        var offset: CGFloat = 0

        for row in 0..<numberOfItems {
            let indexPath = IndexPath(row: row, section: section)
            let itemSize = delegate?.collectionView?(
                collectionView, layout: self, sizeForItemAt: indexPath
            ) ?? self.itemSize

            let itemLength = (scrollDirection == .vertical)
                ? itemSize.width
                : itemSize.height

            // Check if line break is needed
            let next = offset + sectionElement.itemSpacing + itemLength
            if order > 0, next > lineCapacity {
                line += 1
                order = 0
                offset = 0
            }
            // Add spacing
            if order > 0 {
                offset += sectionElement.itemSpacing
            }
            offset += itemLength
            order += 1
            // Create layout attributes
            let layoutAttributes = UICollectionViewLayoutAttributes(
                forCellWith: indexPath
            )
            layoutAttributes.frame = CGRect(origin: .zero, size: itemSize)
            // Add to the current line
            if line < sectionElement.lines.count {
                sectionElement.lines[line].attributes.append(
                    layoutAttributes
                )
            }
            else {
                // Add a new line
                let lineElement = FixedSpacingLineElement()
                lineElement.alignment = sectionElement.alignment
                lineElement.itemSpacing = sectionElement.itemSpacing
                lineElement.attributes.append(layoutAttributes)
                lineElement.lineCapacity = lineCapacity
                sectionElement.lines.append(lineElement)
            }
            // Adjust item size if it exceeds
            adjustItemSizeIfNeeded(
                layoutAttributes, in: collectionView, with: sectionElement
            )
            // Update remaining space in the current line
            sectionElement.lines[line].totalMargin = lineCapacity - offset
            sectionElement.lines[line].sectionInset = sectionElement.sectionInset
            // Store in cache
            cellCache[indexPath] = layoutAttributes
        }
    }

    /// Adjust item size if it exceeds the available width/height (depending on scroll direction)
    private func adjustItemSizeIfNeeded(
        _ attributes: UICollectionViewLayoutAttributes,
        in collectionView: UICollectionView,
        with sectionElement: FixedSpacingSectionElement
    ) {
        var rect = attributes.frame
        if scrollDirection == .vertical,
           rect.maxX > collectionView.bounds.width - sectionElement.sectionInset.right
        {
            rect.size.width = collectionView.bounds.width
                - sectionElement.sectionInset.left
                - sectionElement.sectionInset.right
            attributes.frame = rect
        } else if scrollDirection == .horizontal,
                  rect.maxY > collectionView.bounds.height - sectionElement.sectionInset.bottom
        {
            rect.size.height = collectionView.bounds.height
                - sectionElement.sectionInset.top
                - sectionElement.sectionInset.bottom
            attributes.frame = rect
        }
    }

    /// Prefetches and positions all items, headers, and footers for each section.
    /// Updates the internal caches (`cellCache`, `supplementaryViewCache`) and layout attributes
    /// required for rendering the collection view.
    private func prefetchAllItems() {
        guard let collectionView else { return }

        cellCache.removeAll()
        supplementaryViewCache = [
            UICollectionView.elementKindSectionHeader: [:],
            UICollectionView.elementKindSectionFooter: [:]
        ]

        var offset: CGFloat = 0
        for sectionElement in sectionElements {
            let max: CGFloat
            if sectionElement.alignment == .left
                || sectionElement.alignment == .center
                || sectionElement.alignment == .right
            {
                max = collectionView.frame.size.width
            } else {
                max = collectionView.frame.size.height
            }

            offset = sectionElement.locateHeader(offset: offset)
            offset = sectionElement.locateLines(max: max, offset: offset)
            offset = sectionElement.locateFooter(offset: offset)

            // Cache cell attributes
            for attr in sectionElement.cellsLayoutAttrributesList {
                cellCache[attr.indexPath] = attr
            }

            // Cache header/footer
            if let attr = sectionElement.headerLayoutAttrributes {
                supplementaryViewCache[kHeader]?[attr.indexPath] = attr
            }
            if let attr = sectionElement.footerLayoutAttrributes {
                supplementaryViewCache[kFooter]?[attr.indexPath] = attr
            }
        }
    }

    /// Creates and configures a `FixedSpacingSectionElement` for the given section.
    /// It retrieves spacing, insets, and alignment information from the collection view's delegate
    /// or falls back to default layout properties.
    ///
    /// - Parameters:
    ///   - section: The index of the section to configure.
    ///   - collectionView: The collection view that provides layout information.
    /// - Returns: A configured `FixedSpacingSectionElement` for the specified section.
    private func createSectionElement(
        section: Int, collectionView: UICollectionView
    ) -> FixedSpacingSectionElement {
        let sectionElement = FixedSpacingSectionElement()
        let delegate: UICollectionViewDelegateFlowLayout?
        if let aDelegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
            delegate = aDelegate
        } else {
            delegate = nil
        }
        // line spacing
        if let flowLayoutLineSpacing = delegate?.collectionView?(
            collectionView, layout: self, minimumLineSpacingForSectionAt: section
        ) {
            sectionElement.lineSpacing = flowLayoutLineSpacing
        }
        else {
            sectionElement.lineSpacing = minimumLineSpacing
        }
        // item spacing
        if let flowLayoutInterItemSpacing = delegate?.collectionView?(
            collectionView, layout: self, minimumInteritemSpacingForSectionAt: section
        ) {
            sectionElement.itemSpacing = flowLayoutInterItemSpacing
        }
        else {
            sectionElement.itemSpacing = minimumInteritemSpacing
        }
        // section inset
        if let flowLayoutInset = delegate?.collectionView?(
            collectionView, layout: self, insetForSectionAt: section
        ) {
            sectionElement.sectionInset = flowLayoutInset
        }
        else {
            sectionElement.sectionInset = sectionInset
        }
        // alignment
        if let alignmentProvider {
            sectionElement.alignment = validateAlignment(alignmentProvider(section))
        } else {
            sectionElement.alignment = validateAlignment(alignment)
        }
        // limit of rows
        if let limitOfRowsProvider {
            sectionElement.limitOfRows = limitOfRowsProvider(section)
        } else {
            sectionElement.limitOfRows = limitOfRows
        }

        return sectionElement
    }
}

extension SSAlignmentFlowLayout {
    /// Represents the alignment of items in the collection view layout.
    /// Supports both horizontal (left/center/right) and vertical (top/middle/bottom) orientations.
    public enum Alignment: String, Equatable {
        /// Align items to the left (for vertical layouts).
        case left
        /// Align items to the center horizontally.
        case center
        /// Align items to the right (for vertical layouts).
        case right
        /// Align items to the top (for horizontal layouts)
        case top
        /// Align items to the vertical center.
        case middle
        /// Align items to the bottom (for horizontal layouts).
        case bottom

        /// Indicates whether the current alignment is vertical (left/center/right).
        public var isVertical: Bool {
            switch self {
            case .left, .center, .right:
                return true
            case .top, .middle, .bottom:
                return false
            }
        }
    }
}

/// Represents layout metadata for a single section in the collection view.
/// Stores information such as lines, header/footer attributes, spacing, and section size.
/// This class is used during layout calculation to determine item placement within a section.
@MainActor
private final class FixedSpacingSectionElement {
    var sectionInset: UIEdgeInsets = .zero
    var lineSpacing: CGFloat = 0
    var itemSpacing: CGFloat = 0
    var headerReferenceSize: CGSize = .zero
    var footerReferenceSize: CGSize = .zero

    /// The lines (rows or columns) within the section
    var lines: [FixedSpacingLineElement] = []
    /// Layout attributes for the section header, if any.
    var headerLayoutAttrributes: UICollectionViewLayoutAttributes?
    /// Layout attributes for the section footer, if any.
    var footerLayoutAttrributes: UICollectionViewLayoutAttributes?
    /// A list of all cell layout attributes within this section.
    var cellsLayoutAttrributesList: [UICollectionViewLayoutAttributes] = []

    /// The current alignment type used by the flow layout (default is `.left`).
    var alignment: SSAlignmentFlowLayout.Alignment = .left

    /// The maximum number of rows allowed per section (0 means unlimited).
    var limitOfRows: Int = 0

    /// The overall bounding rectangle of all items (including header/footer) in the section.
    var cellsRect: CGRect = .zero

    var sectionSize: CGSize {
        alignment.isVertical
            ? CGSize(width: cellsRect.width, height: headerReferenceSize.height + cellsRect.height + footerReferenceSize.height)
            : CGSize(width: headerReferenceSize.width + cellsRect.width + footerReferenceSize.width, height: cellsRect.height)
    }

    private var contentMax: CGFloat {
        alignment.isVertical
            ? cellsLayoutAttrributesList.map { $0.frame.maxY }.max() ?? 0
            : cellsLayoutAttrributesList.map { $0.frame.maxX }.max() ?? 0
    }

    /// Positions the header for the current section starting at the given offset.
    ///
    /// - Parameter offset: The starting offset (x or y) where the section header begins.
    /// - Returns: The new offset (maxX or maxY) after placing the header.
    func locateHeader(offset: CGFloat) -> CGFloat {
        if alignment.isVertical {
            headerLayoutAttrributes?.frame = CGRect(
                origin: CGPoint(x: 0, y: offset),
                size: CGSize(width: headerReferenceSize.width,
                             height: headerReferenceSize.height)
            )
            return offset + headerReferenceSize.height
        } else {
            headerLayoutAttrributes?.frame = CGRect(
                origin: CGPoint(x: offset, y: 0),
                size: CGSize(width: headerReferenceSize.width,
                             height: headerReferenceSize.height)
            )
            return offset + headerReferenceSize.width
        }
    }

    /// Positions the footer for the current section based on the given offset.
    ///
    /// - Parameter offset: The offset value where the footer should be placed,
    ///   typically the maxX or maxY of the last cell frame plus the section's right or bottom inset.
    /// - Returns: The new offset (maxX or maxY) after placing the footer.
    func locateFooter(offset: CGFloat) -> CGFloat {
        if alignment.isVertical {
            footerLayoutAttrributes?.frame = CGRect(
                origin: CGPoint(x: 0, y: offset),
                size: CGSize(width: footerReferenceSize.width,
                             height: footerReferenceSize.height)
            )
            return offset + footerReferenceSize.height
        } else {
            footerLayoutAttrributes?.frame = CGRect(
                origin: CGPoint(x: offset, y: 0),
                size: CGSize(width: footerReferenceSize.width,
                             height: footerReferenceSize.height)
            )
            return offset + footerReferenceSize.width
        }
    }

    /// Positions all lines (rows or columns) of items within the section
    /// based on the given offset and available space.
    ///
    /// - Parameters:
    ///   - max: The available layout dimension (width or height of the collection view).
    ///   - offset: The starting offset (x or y) from where the section begins.
    /// - Returns: The new offset (maxY or maxX) after placing all lines of items.
    func locateLines(max: CGFloat, offset: CGFloat) -> CGFloat {
        guard lines.isEmpty == false else { return offset }

        var (xOffset, yOffset) = initialOffsets(offset: offset)

        for (lineIndex, line) in lines.enumerated() {
            if limitOfRows > 0, lineIndex >= limitOfRows { break }

            line.locateItems(xOffset: xOffset, yOffset: yOffset)
            if alignment.isVertical {
                yOffset += line.maxLength + lineSpacing
            } else {
                xOffset += line.maxLength + lineSpacing
            }
            cellsLayoutAttrributesList.append(
                contentsOf: line.attributes
            )
        }

        cellsRect = calculateCellsRect(offset: offset, max: max)
        return offset + (alignment.isVertical ? cellsRect.height : cellsRect.width)
    }

    /// Calculates the initial x and y offsets for positioning lines within a section,
    /// based on the current alignment and starting offset.
    ///
    /// - Parameter offset: The starting offset (x or y) where the section begins.
    /// - Returns: A tuple `(xOffset, yOffset)` representing the initial horizontal and vertical offsets.
    private func initialOffsets(offset: CGFloat) -> (CGFloat, CGFloat) {
        if alignment.isVertical {
            return (sectionInset.left, offset + sectionInset.top)
        } else {
            return (offset + sectionInset.left, sectionInset.top)
        }
    }

    /// Calculates the rectangle (frame) that encompasses all cells within a section,
    /// including applied insets and alignment settings.
    ///
    /// - Parameters:
    ///   - offset: The starting offset (x or y) where the section begins.
    ///   - max: The total available width or height of the collection view's layout area.
    ///   - contentMax: The maximum extent (width or height) of the cells' frames within the section.
    /// - Returns: A CGRect representing the total area occupied by the section's cells.
    private func calculateCellsRect(offset: CGFloat, max: CGFloat) -> CGRect {
        let rect: CGRect
        if alignment.isVertical {
            rect = CGRect(
                origin: CGPoint(x: 0, y: offset),
                size: CGSize(width: max,
                             height: sectionInset.bottom + contentMax - offset)
            )
        } else {
            rect = CGRect(
                origin: CGPoint(x: offset, y: 0),
                size: CGSize(width: sectionInset.right + contentMax - offset,
                             height: max)
            )
        }
        return rect
    }
}

/// Represents layout information for a single line (row or column) within a section.
/// Manages the item attributes, spacing, and alignment required to layout items in that line.
@MainActor
private final class FixedSpacingLineElement {
    /// The alignment of items in this line
    var alignment: SSAlignmentFlowLayout.Alignment = .left
    /// The spacing between items within this line.
    var itemSpacing: CGFloat = 0
    /// The remaining space (margin) in this line after laying out items.
    var totalMargin: CGFloat?
    /// Insets applied around the section containing this line.
    var sectionInset: UIEdgeInsets = .zero
    /// The total capacity (width or height) available for this line.
    var lineCapacity: CGFloat = 0
    /// A list of layout attributes representing all items in this line.
    var attributes: [UICollectionViewLayoutAttributes] = []

    /// The maximum length (height or width) of the items in this line.
    var maxLength: CGFloat {
        attributes.reduce(0) {
            max($0, alignment.isVertical ? $1.size.height : $1.size.width)
        }
    }
    /// The offset where the first item starts, considering alignment and total margin.
    private var startingOffset: CGFloat {
        guard let totalMargin else { return 0 }
        switch alignment {
        case .left, .top: return 0
        case .center, .middle: return totalMargin / 2
        case .right, .bottom: return totalMargin
        }
    }

    /// Positions all layout attributes (cells) within a line starting from the given offsets.
    /// Adjusts the x or y positions based on the current alignment and item spacing.
    ///
    /// - Parameters:
    ///   - xOffset: The initial x-coordinate where the first item should be placed.
    ///   - yOffset: The initial y-coordinate where the first item should be placed.
    func locateItems(xOffset: CGFloat, yOffset: CGFloat) {
        var xPos = alignment.isVertical
            ? sectionInset.left + startingOffset
            : xOffset
        var yPos = alignment.isVertical
            ? yOffset
            : sectionInset.top + startingOffset

        for layoutAttributes in attributes {
            layoutAttributes.frame = CGRect(
                origin: CGPoint(x: xPos, y: yPos),
                size: CGSize(width: layoutAttributes.size.width,
                             height: layoutAttributes.size.height)
            )
            if alignment.isVertical {
                xPos += layoutAttributes.size.width + itemSpacing
            } else {
                yPos += layoutAttributes.size.height + itemSpacing
            }
        }
    }
}
