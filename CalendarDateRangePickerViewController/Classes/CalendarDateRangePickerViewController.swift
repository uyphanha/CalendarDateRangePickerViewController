//
//  CalendarDateRangePickerViewController.swift
//  CalendarDateRangePickerViewController
//
//  Created by Miraan on 15/10/2017.
//  Copyright © 2017 Miraan. All rights reserved.
//

import UIKit

public protocol CalendarDateRangePickerViewControllerDelegate {
    func didCancelPickingDateRange()
    func didPickDateRange(startDate: Date?, endDate: Date?)
}

open class CalendarDateRangePickerViewController: UICollectionViewController {
    
    let cellReuseIdentifier = "CalendarDateRangePickerCell"
    let headerReuseIdentifier = "CalendarDateRangePickerHeaderView"
    
    public var delegate: CalendarDateRangePickerViewControllerDelegate!
    
    let itemsPerRow = 7
    let itemHeight: CGFloat = 40
    let collectionViewInsets = UIEdgeInsets(top: 0, left: 25, bottom: 0, right: 25)
    
    public var isAbsoluteStartOfMonth: Bool = false
    public var enabledSetNoDates: Bool = false
    public var minimumDate: Date!
    public var maximumDate: Date! {
        didSet {
            self.endOfMonthMaximumDate = self.maximumDate.endOfMonth()
        }
    }
    
    fileprivate var endOfMonthMaximumDate: Date!
    
    public var selectedStartDate: Date? {
        didSet {
            self.validateSelectedDates()
        }
    }
    public var selectedEndDate: Date? {
        didSet {
            self.validateSelectedDates()
        }
    }
  
    public var titleText = "Select Dates"
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.titleText
        
        collectionView?.dataSource = self
        collectionView?.delegate = self
        collectionView?.backgroundColor = CalendarDateRangeAppearance.appearance.backgroundColor
        
        collectionView?.register(CalendarDateRangePickerCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
        collectionView?.register(CalendarDateRangePickerHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerReuseIdentifier)
        collectionView?.contentInset = collectionViewInsets
        
        if minimumDate == nil {
            minimumDate = Date()
        }
        if maximumDate == nil {
            maximumDate = Calendar.current.date(byAdding: .year, value: 3, to: minimumDate)
        }
        
        if isAbsoluteStartOfMonth {
            self.minimumDate = self.minimumDate.startOfMonth()
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.didTapCancel))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.didTapDone))
        self.validateSelectedDates()
        
        DispatchQueue.main.async {
            self.shouldScroolToSelectedDate()
        }
    }
    
    private func validateSelectedDates () {
        if self.enabledSetNoDates { return }
        
        self.navigationItem.rightBarButtonItem?.isEnabled = self.selectedStartDate != nil || self.selectedEndDate != nil
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.shouldScroolToSelectedDate()
    }
    
    @objc func didTapCancel() {
        delegate.didCancelPickingDateRange()
    }
    
    @objc func didTapDone() {
        if !self.enabledSetNoDates && self.selectedEndDate == nil && self.selectedEndDate == nil {
            return
        }
        
        delegate.didPickDateRange(startDate: selectedStartDate, endDate: selectedEndDate)
    }
}

extension CalendarDateRangePickerViewController {
    
    // UICollectionViewDataSource
    
    override public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.getNumberSection(from: self.minimumDate, to: self.endOfMonthMaximumDate)
    }
    
    override public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let firstDateForSection = getFirstDateForSection(section: section)
        let weekdayRowItems = 7
        let blankItems = getWeekday(date: firstDateForSection) - 1
        let daysInMonth = getNumberOfDaysInMonth(date: firstDateForSection)
        return weekdayRowItems + blankItems + daysInMonth
    }
    
    override public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! CalendarDateRangePickerCell
        cell.reset()
        
        let blankItems = getWeekday(date: getFirstDateForSection(section: indexPath.section)) - 1
        if indexPath.item < 7 {
            cell.label.text = getWeekdayLabel(weekday: indexPath.item + 1)
            cell.dayOfWeekAppearance = CalendarDateRangeAppearance.appearance.dayOfWeekAppearance
        } else if indexPath.item < 7 + blankItems {
            cell.label.text = ""
        } else {
            let dayOfMonth = indexPath.item - (7 + blankItems) + 1
            let date = getDate(dayOfMonth: dayOfMonth, section: indexPath.section)
            cell.date = date
            cell.label.text = "\(dayOfMonth)"
            
            if isBefore(dateA: date, dateB: self.minimumDate) || isAfter(dateA: date, dateB: self.maximumDate) {
                cell.disable()
            }
            
            if selectedStartDate != nil && selectedEndDate != nil && isBefore(dateA: selectedStartDate!, dateB: date) && isBefore(dateA: date, dateB: selectedEndDate!) {
                // Cell falls within selected range
                if dayOfMonth == 1 {
                    cell.highlightRight()
                } else if dayOfMonth == getNumberOfDaysInMonth(date: date) {
                    cell.highlightLeft()
                } else {
                    cell.highlight()
                }
            } else if selectedStartDate != nil && areSameDay(dateA: date, dateB: selectedStartDate!) {
                // Cell is selected start date
                if selectedEndDate != nil {
                    if areSameDay(dateA: self.selectedStartDate!, dateB: self.selectedEndDate!) {
                        cell.select()
                    } else {
                        cell.select(true)
                        cell.highlightRight()
                    }
                } else {
                    cell.select(true)
                    cell.highlightRight()
                }
            } else if selectedEndDate != nil && areSameDay(dateA: date, dateB: selectedEndDate!) {
                cell.select(false)
                cell.highlightLeft()
            } else if (self.areSameDay(dateA: date, dateB: Date())) { // Highlight Today
                cell.highlightToday()
            }
        }
        return cell
    }
    
    override public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerReuseIdentifier, for: indexPath) as! CalendarDateRangePickerHeaderView
            headerView.label.text = getMonthLabel(date: getFirstDateForSection(section: indexPath.section))
            return headerView
        default:
            fatalError("Unexpected element kind")
        }
    }
}

extension CalendarDateRangePickerViewController : UICollectionViewDelegateFlowLayout {
    
    override public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let blankItems = getWeekday(date: getFirstDateForSection(section: indexPath.section)) - 1
        if indexPath.item < 7 + blankItems { // Day of week and empty cells
            return
        }
        let cell = collectionView.cellForItem(at: indexPath) as! CalendarDateRangePickerCell
        if (cell.date == nil) {
            return
        }
        if isBefore(dateA: cell.date!, dateB: self.minimumDate) || isAfter(dateA: cell.date!, dateB: self.maximumDate) {
            return
        }
        if selectedStartDate == nil {
            selectedStartDate = cell.date
        } else if selectedEndDate == nil {
            if isBefore(dateA: selectedStartDate!, dateB: cell.date!) {
                selectedEndDate = cell.date
            } else {
                // If a cell before the currently selected start date is selected then just set it as the new start date
                selectedEndDate = selectedStartDate
                selectedStartDate = cell.date
            }
        } else {
            selectedStartDate = self.enabledSetNoDates ? nil : cell.date
            selectedEndDate = nil
        }
        collectionView.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding = collectionViewInsets.left + collectionViewInsets.right
        let availableWidth = view.frame.width - padding
        let itemWidth = availableWidth / CGFloat(itemsPerRow)
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: view.frame.size.width, height: 50)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
}

extension CalendarDateRangePickerViewController {
    
    // Helper functions
    
//    func getFirstDate() -> Date {
//        var components = Calendar.current.dateComponents([.month, .year], from: minimumDate)
//        components.day = 1
//        return Calendar.current.date(from: components)!
//    }
    
    func getNumberSection(from date1: Date, to date2: Date) -> Int {
        let difference = Calendar.current.dateComponents([.month], from: date1, to: date2)
        return difference.month! + 1
    }
    
    func getFirstDateForSection(section: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: section, to: minimumDate.startOfMonth())!
    }
    
    func getMonthLabel(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }
    
    func getWeekdayLabel(weekday: Int) -> String {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.weekday = weekday
        let date = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: Calendar.MatchingPolicy.strict)
        if date == nil {
            return "E"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = CalendarDateRangeAppearance.appearance.dayOfWeekAppearance.format
        return dateFormatter.string(from: date!)
    }
    
    func getWeekday(date: Date) -> Int {
        return Calendar.current.dateComponents([.weekday], from: date).weekday!
    }
    
    func getNumberOfDaysInMonth(date: Date) -> Int {
        return Calendar.current.range(of: .day, in: .month, for: date)!.count
    }
    
    func getDate(dayOfMonth: Int, section: Int) -> Date {
        var components = Calendar.current.dateComponents([.month, .year], from: getFirstDateForSection(section: section))
        components.day = dayOfMonth
        return Calendar.current.date(from: components)!
    }
    
    func areSameDay(dateA: Date, dateB: Date) -> Bool {
        return Calendar.current.compare(dateA, to: dateB, toGranularity: .day) == ComparisonResult.orderedSame
    }
    
    func isBefore(dateA: Date, dateB: Date) -> Bool {
        return Calendar.current.compare(dateA, to: dateB, toGranularity: .day) == ComparisonResult.orderedAscending
    }
    
    func isAfter(dateA: Date, dateB: Date) -> Bool {
        return Calendar.current.compare(dateA, to: dateB, toGranularity: .day) == ComparisonResult.orderedDescending
    }
    
    fileprivate func shouldScroolToSelectedDate() {
        var section = 0
        if self.selectedStartDate != nil {
            section = self.getNumberSection(from: self.minimumDate, to: self.selectedStartDate!.endOfMonth()) - 1
        } else {
            section = self.getNumberSection(from: self.minimumDate, to: Date().endOfMonth()) - 1
        }
        
        if let collectionView = self.collectionView, (self.numberOfSections(in: collectionView)) < section {
            return
        }
        
        self.collectionView?.scrollToItem(at: IndexPath(row: 0, section: section), at: .centeredVertically, animated: false)
    }
}

extension Date {
    
    func startOfMonth() -> Date {
        if let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: self))) {
            return startOfMonth
        }
        return self
    }
    
    func endOfMonth() -> Date {
        if let endOfMonth = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth()) {
            return endOfMonth
        }
        return self
    }
}
