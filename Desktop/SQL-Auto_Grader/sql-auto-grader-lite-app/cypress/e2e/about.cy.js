describe('About Page', () => {
  it('loads successfully', () => {
    cy.visit('/about');
    cy.url().should('include', '/about');
  });
});
