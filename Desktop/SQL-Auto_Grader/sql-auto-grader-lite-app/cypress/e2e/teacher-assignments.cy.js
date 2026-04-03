describe('Teacher Assignments Page', () => {
  beforeEach(() => {
    cy.loginAsTeacher();
    cy.visit('/dashboard/assignments');
  });

  it('loads assignments page', () => {
    cy.url().should('include', '/dashboard/assignments');
  });

  it('shows Create Assignment button', () => {
    cy.contains('Create Assignment').should('be.visible');
  });

  it('opens assignment form with tabs', () => {
    cy.contains('Create Assignment').click();
    cy.contains('.react-tabs__tab', 'Create Assignment').should('be.visible');
    cy.contains('.react-tabs__tab', 'Add Questions').should('be.visible');
    cy.contains('.react-tabs__tab', 'Assign Students').should('be.visible');
  });

  it('Add Questions tab is disabled until title and due date are filled', () => {
    cy.contains('Create Assignment').click();
    cy.contains('.react-tabs__tab', 'Add Questions').should('have.attr', 'aria-disabled', 'true');
  });

  it('enables Add Questions tab after filling required fields', () => {
    cy.contains('Create Assignment').click();
    cy.get('input[name="title"]').type('Test Assignment');
    cy.get('input[name="due_date"]').type('2027-01-01');
    cy.contains('button', 'Next').click();
    cy.contains('.react-tabs__tab--selected', 'Add Questions');
  });
});
