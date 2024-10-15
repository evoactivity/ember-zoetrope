export function getRelativeBoundingClientRect(
  childElement: Element,
  parentElement: Element,
) {
  if (!childElement || !parentElement) {
    throw new Error('Both childElement and parentElement must be provided');
  }

  // Get the bounding rect of the child and parent elements
  const childRect = childElement.getBoundingClientRect();
  const parentRect = parentElement.getBoundingClientRect();

  // Get computed styles of the parent element
  const parentStyles = window.getComputedStyle(parentElement);

  // Extract and parse parent's padding, and border, for all sides
  const parentPaddingTop = parseFloat(parentStyles.paddingTop);
  const parentPaddingLeft = parseFloat(parentStyles.paddingLeft);

  const parentBorderTopWidth = parseFloat(parentStyles.borderTopWidth);
  const parentBorderLeftWidth = parseFloat(parentStyles.borderLeftWidth);

  // Calculate child's position relative to parent's content area (including padding and borders)
  return {
    width: childRect.width,
    height: childRect.height,
    top:
      childRect.top - parentRect.top - parentBorderTopWidth - parentPaddingTop,
    left:
      childRect.left -
      parentRect.left -
      parentBorderLeftWidth -
      parentPaddingLeft,
    bottom:
      childRect.top -
      parentRect.top -
      parentBorderTopWidth -
      parentPaddingTop +
      childRect.height,
    right:
      childRect.left -
      parentRect.left -
      parentBorderLeftWidth -
      parentPaddingLeft +
      childRect.width,
  };
}
