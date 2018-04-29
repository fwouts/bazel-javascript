function dependenciesMap(externalDeps) {
  return externalDeps.reduce((acc, curr) => {
    if (!curr) {
      return acc;
    }
    const atSignPosition = curr.lastIndexOf("@");
    if (atSignPosition === -1) {
      throw new Error(`Expected @ sign in ${curr}.`);
    }
    const package = curr.substr(0, atSignPosition);
    const version = curr.substr(atSignPosition + 1);
    if (acc[package] && acc[package] !== version) {
      throw new Error(
        `Mismatching versions of the same package ${package}: ${
          acc[package]
        } and ${version}.`
      );
    }
    return {
      ...acc,
      [package]: version
    };
  }, {});
}

module.exports = {
  dependenciesMap
};
