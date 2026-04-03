describe('Student Results Page', () => {
  beforeEach(() => {
    cy.loginAsStudent();
    cy.visit('/dashboard/results');
  });

  it('loads results page', () => {
    cy.url().should('include', '/dashboard/results');
    cy.contains('Submitted Assignments').should('be.visible');
  });

  it('shows results table columns', () => {
    cy.contains('Title').should('be.visible');
    cy.contains('Percentage').should('be.visible');
  });
});
