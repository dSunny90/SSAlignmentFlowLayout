//
//  SSAlignmentFlowLayoutTests.swift
//  SSAlignmentFlowLayout
//
//  Created by SunSoo Jeon on 24.02.2021.
//

import XCTest
@testable import SSAlignmentFlowLayout
import UIKit

final class SSAlignmentFlowLayoutTests: XCTestCase {
    func testAlignment() {
        let layout = SSAlignmentFlowLayout(
            alignmentProvider: { section in
                return section == 0 ? .left : .right
            }
        )
        layout.itemSize = CGSize(width: 100, height: 50)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = .zero

        let frame = CGRect(x: 0, y: 0, width: 400, height: 1000)
        let collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        collectionView.register(TestCell.self, forCellWithReuseIdentifier: "TestCell")
        collectionView.dataSource = self
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let attributes = layout.layoutAttributesForElements(in: collectionView.bounds) ?? []

        let lineWidth: CGFloat = frame.width - layout.sectionInset.left - layout.sectionInset.right
        let numberOfItemsInLine = Int(floor((lineWidth + layout.minimumInteritemSpacing) / (layout.itemSize.width + layout.minimumInteritemSpacing))) // 3

        for attribute in attributes {
            let section = attribute.indexPath.section
            let row = attribute.indexPath.row
            if section == 0, row == 0 {
                XCTAssertEqual(attribute.frame.minX, frame.minX + layout.sectionInset.left, "Section 0 should align to left")
            } else if section == 0, row == numberOfItemsInLine {
                XCTAssertEqual(attribute.frame.minX, frame.minX + layout.sectionInset.left, "Section 0 should align to left")
            } else if section == 1, row == numberOfItemsInLine - 1 {
                XCTAssertEqual(attribute.frame.maxX, frame.maxX - layout.sectionInset.right, "Section 1 should align to right")
            } else if section == 1, row == numberOfItemsInLine * 2 - 1 {
                XCTAssertEqual(attribute.frame.maxX, frame.maxX - layout.sectionInset.right, "Section 1 should align to right")
            }
        }
    }

    func testLimitOfRows() {
        let layout = SSAlignmentFlowLayout(alignment: .left, limitOfRows: 1)
        layout.itemSize = CGSize(width: 100, height: 50)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = .zero

        let frame = CGRect(x: 0, y: 0, width: 400, height: 1000)
        let collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        collectionView.register(TestCell.self, forCellWithReuseIdentifier: "TestCell")
        collectionView.dataSource = self
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let attributes = layout.layoutAttributesForElements(in: collectionView.bounds) ?? []
        let rows = Set(attributes.map { $0.frame.origin.y })

        let lineWidth: CGFloat = frame.width - layout.sectionInset.left - layout.sectionInset.right
        let numberOfItemsInLine = Int(floor((lineWidth + layout.minimumInteritemSpacing) / (layout.itemSize.width + layout.minimumInteritemSpacing))) // 3
        let numberOfSections = self.numberOfSections(in: collectionView) // 2

        XCTAssertEqual(attributes.count, numberOfItemsInLine * numberOfSections, "numberOfItemsInLine * numberOfSections items should be laid out.")
        XCTAssertEqual(rows.count, numberOfSections, "rows should be number of sections")
    }
}

extension SSAlignmentFlowLayoutTests: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 10
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TestCell", for: indexPath)
        return cell
    }
}

private final class TestCell: UICollectionViewCell {}
