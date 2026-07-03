// FILE: Sources/CookiePrimeConsent/UI/ConsentViewController.swift
#if canImport(UIKit)
import UIKit

// MARK: - Delegate Protocol

public protocol ConsentViewControllerDelegate: AnyObject {
    func consentViewController(_ controller: ConsentViewController, didCompleteWithConsent consent: [String: Bool])
    func consentViewControllerDidCancel(_ controller: ConsentViewController)
    func consentViewController(_ controller: ConsentViewController, didFailWithError error: Error)
}

// MARK: - View Controller

public final class ConsentViewController: UIViewController {
    
    // MARK: - Properties
    
    public weak var delegate: ConsentViewControllerDelegate?
    private let viewModel: ConsentViewModel
    
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    private var titleLabel: UILabel!
    private var descriptionLabel: UILabel!
    private var errorLabel: UILabel!
    
    private var acceptAllButton: UIButton!
    private var saveButton: UIButton!
    private var rejectAllButton: UIButton!
    private var loadingIndicator: UIActivityIndicatorView!
    
    private var categoryViews: [String: ConsentCategoryView] = [:]
    
    // MARK: - Initialization
    
    public init(viewModel: ConsentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .formSheet
        if #available(iOS 15.0, *) {
            self.sheetPresentationController?.detents = [.medium(), .large()]
            self.sheetPresentationController?.prefersGrabberVisible = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupNavigationBar()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Scroll View
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        // Stack View
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Title
        titleLabel = UILabel()
        titleLabel.text = "Privacy Choices"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stackView.addArrangedSubview(titleLabel)
        
        // Description
        descriptionLabel = UILabel()
        descriptionLabel.text = "We respect your privacy. Choose which data processing activities you allow."
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(descriptionLabel)
        
        // Divider
        let divider = createDivider()
        stackView.addArrangedSubview(divider)
        
        // Categories
        for category in viewModel.categories {
            let categoryView = ConsentCategoryView(category: category)
            categoryView.delegate = self
            categoryViews[category.id] = categoryView
            stackView.addArrangedSubview(categoryView)
        }
        
        // Error Label
        errorLabel = UILabel()
        errorLabel.textColor = .systemRed
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        stackView.addArrangedSubview(errorLabel)
        
        // Divider
        let divider2 = createDivider()
        stackView.addArrangedSubview(divider2)
        
        // Button Stack
        let buttonStack = UIStackView()
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        stackView.addArrangedSubview(buttonStack)
        
        // Accept All Button
        acceptAllButton = createButton(
            title: "Accept All",
            style: .primary
        )
        acceptAllButton.addTarget(self, action: #selector(didTapAcceptAll), for: .touchUpInside)
        buttonStack.addArrangedSubview(acceptAllButton)
        
        // Save Button
        saveButton = createButton(
            title: "Save Selection",
            style: .secondary
        )
        saveButton.addTarget(self, action: #selector(didTapSaveSelections), for: .touchUpInside)
        buttonStack.addArrangedSubview(saveButton)
        
        // Reject All Button
        rejectAllButton = createButton(
            title: "Reject All",
            style: .text
        )
        rejectAllButton.addTarget(self, action: #selector(didTapRejectAll), for: .touchUpInside)
        buttonStack.addArrangedSubview(rejectAllButton)
        
        // Loading Indicator
        loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupBindings() {
        viewModel.$isSaving
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSaving in
                self?.updateLoadingState(isSaving)
            }
            .store(in: &cancellables)
        
        viewModel.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
        
        viewModel.$hasChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasChanges in
                self?.updateSaveButton(enabled: hasChanges)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Helpers
    
    private var cancellables = Set<AnyCancellable>()
    
    private func createDivider() -> UIView {
        let divider = UIView()
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        divider.backgroundColor = .separator
        return divider
    }
    
    private enum ButtonStyle {
        case primary
        case secondary
        case text
    }
    
    private func createButton(title: String, style: ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        
        switch style {
        case .primary:
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
            
        case .secondary:
            button.backgroundColor = .systemGray6
            button.setTitleColor(.label, for: .normal)
            button.setTitleColor(.label.withAlphaComponent(0.7), for: .highlighted)
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.separator.cgColor
            
        case .text:
            button.backgroundColor = .clear
            button.setTitleColor(.systemRed, for: .normal)
            button.setTitleColor(.systemRed.withAlphaComponent(0.7), for: .highlighted)
        }
        
        return button
    }
    
    private func updateUI() {
        let granted = viewModel.categories.filter { $0.isEnabled }.count
        let total = viewModel.categories.count
        let summary = "\(granted) of \(total) categories selected"
        descriptionLabel.text = summary
    }
    
    private func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
            view.isUserInteractionEnabled = false
            saveButton.isEnabled = false
        } else {
            loadingIndicator.stopAnimating()
            view.isUserInteractionEnabled = true
            updateSaveButton(enabled: viewModel.hasChanges)
        }
    }
    
    private func updateSaveButton(enabled: Bool) {
        saveButton.isEnabled = enabled
        saveButton.alpha = enabled ? 1.0 : 0.5
    }
    
    private func showError(_ error: String?) {
        if let error = error {
            errorLabel.text = error
            errorLabel.isHidden = false
        } else {
            errorLabel.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func didTapAcceptAll() {
        viewModel.acceptAll()
        updateUI()
        updateCategoryViews()
        
        // Visual feedback
        UIView.animate(withDuration: 0.3) {
            self.acceptAllButton.backgroundColor = .systemGreen
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.acceptAllButton.backgroundColor = .systemBlue
            }
        }
    }
    
    @objc private func didTapRejectAll() {
        viewModel.rejectAll()
        updateUI()
        updateCategoryViews()
        
        // Visual feedback
        UIView.animate(withDuration: 0.3) {
            self.rejectAllButton.setTitleColor(.systemGreen, for: .normal)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.rejectAllButton.setTitleColor(.systemRed, for: .normal)
            }
        }
    }
    
    @objc private func didTapSaveSelections() {
        guard viewModel.hasConsentChanged() else {
            delegate?.consentViewControllerDidCancel(self)
            return
        }
        
        Task { @MainActor in
            do {
                try await viewModel.saveConsent()
                let consent = viewModel.getCurrentConsent()
                delegate?.consentViewController(self, didCompleteWithConsent: consent)
                await dismiss(animated: true)
            } catch {
                delegate?.consentViewController(self, didFailWithError: error)
            }
        }
    }
    
    private func updateCategoryViews() {
        for category in viewModel.categories {
            if let view = categoryViews[category.id] {
                view.update(category: category)
            }
        }
    }
}

// MARK: - ConsentCategoryViewDelegate

extension ConsentViewController: ConsentCategoryViewDelegate {
    func consentCategoryView(_ view: ConsentCategoryView, didToggleCategory category: ConsentCategory) {
        viewModel.toggleCategory(category.id)
        updateUI()
    }
}

// MARK: - Consent Category View

protocol ConsentCategoryViewDelegate: AnyObject {
    func consentCategoryView(_ view: ConsentCategoryView, didToggleCategory category: ConsentCategory)
}

class ConsentCategoryView: UIView {
    
    // MARK: - Properties
    
    private var category: ConsentCategory
    private weak var delegate: ConsentCategoryViewDelegate?
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let switchControl = UISwitch()
    private let containerView = UIView()
    
    // MARK: - Initialization
    
    init(category: ConsentCategory) {
        self.category = category
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        containerView.backgroundColor = .systemGray6
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Description
        descriptionLabel.font = .preferredFont(forTextStyle: .caption1)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // Switch
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        containerView.addSubview(switchControl)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: switchControl.leadingAnchor, constant: -8),
            
            switchControl.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        updateUI()
    }
    
    private func updateUI() {
        titleLabel.text = category.name
        descriptionLabel.text = category.description
        switchControl.isOn = category.isEnabled
        switchControl.isEnabled = !category.required
        switchControl.accessibilityLabel = category.required ? "\(category.name) (Required)" : category.name
        
        // Show required badge
        if category.required {
            titleLabel.text = "\(category.name) *"
            titleLabel.textColor = .label
        } else {
            titleLabel.textColor = .label
        }
    }
    
    func update(category: ConsentCategory) {
        self.category = category
        updateUI()
    }
    
    @objc private func switchValueChanged() {
        var updatedCategory = category
        updatedCategory.isEnabled = switchControl.isOn
        delegate?.consentCategoryView(self, didToggleCategory: updatedCategory)
    }
}

// MARK: - Combine Import

import Combine

#endif