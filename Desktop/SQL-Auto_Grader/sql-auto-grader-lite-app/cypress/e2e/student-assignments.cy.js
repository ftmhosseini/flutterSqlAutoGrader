describe('Student Assignments Page', () => {
  beforeEach(() => {
    cy.loginAsStudent();
    cy.visit('/dashboard/assignments');
  });

  it('shows Assignments and Submitted Assignments tabs', () => {
    cy.contains('.react-tabs__tab', 'Assignments').should('be.visible');
    cy.contains('.react-tabs__tab', 'Submitted Assignments').should('be.visible');
  });

  it('Assignments tab is active by default', () => {
    cy.contains('.react-tabs__tab--selected', 'Assignments');
  });

  it('switches to Submitted Assignments tab', () => {
    cy.contains('.react-tabs__tab', 'Submitted Assignments').click();
    cy.contains('.react-tabs__tab--selected', 'Submitted Assignments');
  });

  it('Submitted Assignments tab shows marks and percentage columns', () => {
    cy.contains('.react-tabs__tab', 'Submitted Assignments').click();
    cy.contains('Marks Obtained').should('be.visible');
    cy.contains('Percentage').should('be.visible');
  });
});
